"""Model klasifikasi multi-label jenis kulit (SPEC-ML §8.3).

Fitur : TF-IDF atas token bahan utuh.
Target: 4 label biner (Berminyak_Berjerawat, Kering, Sensitif, Normal).

Modul ini dipakai notebook eksplorasi DAN `scripts/train_classifier.py`,
sehingga konfigurasi yang dipilih di notebook dapat direproduksi apa adanya.
"""

from __future__ import annotations

from typing import Any

import numpy as np

# Model yang boleh dibandingkan di notebook. Kunci -> (kelas, punya predict_proba)
SUPPORTED_MODELS: tuple[str, ...] = ("logreg", "svc", "svc_cal", "nb")


def ingredient_tokens(text: str) -> list[str]:
    """Pecah string bahan kanonik menjadi token utuh.

    Dipisah pada ', ' (koma **dan** spasi), bukan koma saja, agar
    '1,2-hexanediol' tidak terpecah menjadi '1' dan '2-hexanediol'.
    """
    if not text:
        return []
    return [part.strip() for part in text.split(", ") if part.strip()]


def build_pipeline(
    kind: str = "logreg",
    class_weight: str | None = "balanced",
    C: float = 1.0,
    min_df: int = 2,
    max_features: int | None = None,
):
    """Bangun pipeline TF-IDF + classifier one-vs-rest.

    Args:
        kind: 'logreg' (probabilitas), 'svc' (decision_function), 'nb'.
        class_weight: 'balanced' atau None.
        C: regularisasi (logreg/svc).
        min_df: abaikan token yang muncul di kurang dari N produk.
    """
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    from sklearn.multiclass import OneVsRestClassifier
    from sklearn.naive_bayes import ComplementNB
    from sklearn.pipeline import Pipeline
    from sklearn.svm import LinearSVC

    if kind not in SUPPORTED_MODELS:
        raise ValueError(f"kind tidak dikenal: {kind}. Pilihan: {SUPPORTED_MODELS}")

    vectorizer = TfidfVectorizer(
        analyzer=ingredient_tokens,
        lowercase=False,
        min_df=min_df,
        max_features=max_features,
        sublinear_tf=True,
    )

    if kind == "logreg":
        estimator = OneVsRestClassifier(
            LogisticRegression(
                C=C,
                class_weight=class_weight,
                max_iter=2000,
                solver="liblinear",
            )
        )
    elif kind == "svc":
        estimator = OneVsRestClassifier(
            LinearSVC(C=C, class_weight=class_weight, max_iter=5000)
        )
    elif kind == "svc_cal":
        # LinearSVC akurat tetapi tidak menghasilkan probabilitas. Kalibrasi
        # sigmoid memberi skor 0..1 yang bisa dipakai API dan ambang 0,5.
        from sklearn.calibration import CalibratedClassifierCV

        estimator = OneVsRestClassifier(
            CalibratedClassifierCV(
                LinearSVC(C=C, class_weight=class_weight, max_iter=5000), cv=3
            )
        )
    else:
        estimator = OneVsRestClassifier(ComplementNB())

    return Pipeline([("tfidf", vectorizer), ("clf", estimator)])


def predict_scores(pipeline, texts) -> np.ndarray:
    """Skor per label; probabilitas bila tersedia, jika tidak decision_function.

    Nilai SVC tidak berada di rentang 0..1, sehingga penyetelan ambang untuk
    SVC harus memakai ambang 0 (bukan 0,5).
    """
    if hasattr(pipeline, "predict_proba"):
        return np.asarray(pipeline.predict_proba(texts))
    return np.asarray(pipeline.decision_function(texts))


def scores_to_labels(scores: np.ndarray, thresholds) -> np.ndarray:
    """Ubah skor menjadi matriks label biner memakai ambang per label."""
    thresholds = np.asarray(thresholds, dtype=float)
    return (scores >= thresholds).astype(int)


def vocabulary_size(pipeline) -> int:
    return len(pipeline.named_steps["tfidf"].vocabulary_)


def top_features(pipeline, label_index: int, n: int = 12) -> list[tuple[str, float]]:
    """Token paling berpengaruh untuk satu label (koefisien terbesar)."""
    vectorizer = pipeline.named_steps["tfidf"]
    estimator: Any = pipeline.named_steps["clf"]
    names = vectorizer.get_feature_names_out()

    if hasattr(estimator, "estimators_"):
        coef = estimator.estimators_[label_index].coef_.ravel()
    else:
        coef = estimator.coef_[label_index].ravel()

    order = np.argsort(coef)[::-1][:n]
    return [(str(names[i]), float(coef[i])) for i in order]
