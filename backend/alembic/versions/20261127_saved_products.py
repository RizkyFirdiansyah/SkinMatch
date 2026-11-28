"""saved products

Revision ID: 20261127_saved_products
Revises: 20261115_scan_classification_details
Create Date: 2026-11-27 18:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20261127_saved_products"
down_revision: Union[str, Sequence[str], None] = "20261115_scan_classification_details"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "saved_products",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("scan_id", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=True,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["scan_id"], ["scans.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "scan_id", name="uq_saved_products_user_scan"),
    )
    op.create_index(op.f("ix_saved_products_id"), "saved_products", ["id"], unique=False)
    op.create_index(op.f("ix_saved_products_user_id"), "saved_products", ["user_id"], unique=False)
    op.create_index(op.f("ix_saved_products_scan_id"), "saved_products", ["scan_id"], unique=False)


def downgrade() -> None:
    # drop_table ikut menghapus index + FK; MySQL menolak DROP INDEX selama FK
    # masih memakainya.
    op.drop_table("saved_products")
