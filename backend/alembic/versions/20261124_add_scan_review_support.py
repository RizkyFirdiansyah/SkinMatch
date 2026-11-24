"""allow reviews to be linked directly to scans

Revision ID: 20261124_scan_review
Revises: 20261115_scan_classification_details
Create Date: 2026-11-24 04:20:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20261124_scan_review"
down_revision: Union[str, Sequence[str], None] = "20261115_scan_classification_details"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "reviews",
        "product_id",
        existing_type=sa.Integer(),
        nullable=True,
    )
    op.create_unique_constraint(
        "uq_reviews_scan_id",
        "reviews",
        ["scan_id"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_reviews_scan_id", "reviews", type_="unique")
    op.alter_column(
        "reviews",
        "product_id",
        existing_type=sa.Integer(),
        nullable=False,
    )
