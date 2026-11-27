"""scan product name

Revision ID: 20261127_scan_product_name
Revises: 20261127_saved_products
Create Date: 2026-11-27 18:45:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20261127_scan_product_name"
down_revision: Union[str, Sequence[str], None] = "20261127_saved_products"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "scans",
        sa.Column("product_name", sa.String(150), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("scans", "product_name")
