"""persist scan classification details

Revision ID: 20261115_scan_classification_details
Revises: 20261115_profile_demographics
Create Date: 2026-11-15 18:02:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20261115_scan_classification_details"
down_revision: Union[str, Sequence[str], None] = "20261115_profile_demographics"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "scans",
        sa.Column("classification_details", sa.JSON(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("scans", "classification_details")
