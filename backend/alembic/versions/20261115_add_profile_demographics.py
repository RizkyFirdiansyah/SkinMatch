"""add age range and biological sex to user profiles

Revision ID: 20261115_profile_demographics
Revises: 449c42f0a3c8
Create Date: 2026-11-15 17:52:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20261115_profile_demographics"
down_revision: Union[str, Sequence[str], None] = "449c42f0a3c8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("age_range", sa.String(length=10), nullable=True))
    op.add_column("users", sa.Column("biological_sex", sa.String(length=10), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "biological_sex")
    op.drop_column("users", "age_range")
