"""ekipler modulu: teams tablosu, users.team_id, categories.team_id

Revision ID: b1e7f4a92c31
Revises: 839cb395c028
Create Date: 2026-09-11 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b1e7f4a92c31'
down_revision: Union[str, Sequence[str], None] = '839cb395c028'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'teams',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('name'),
    )

    op.add_column('users', sa.Column('team_id', sa.UUID(), nullable=True))
    op.create_index('ix_users_team_id', 'users', ['team_id'])
    op.create_foreign_key('fk_users_team_id', 'users', 'teams', ['team_id'], ['id'])

    op.add_column('categories', sa.Column('team_id', sa.UUID(), nullable=True))
    op.create_index('ix_categories_team_id', 'categories', ['team_id'])
    op.create_foreign_key('fk_categories_team_id', 'categories', 'teams', ['team_id'], ['id'])


def downgrade() -> None:
    op.drop_constraint('fk_categories_team_id', 'categories', type_='foreignkey')
    op.drop_index('ix_categories_team_id', table_name='categories')
    op.drop_column('categories', 'team_id')

    op.drop_constraint('fk_users_team_id', 'users', type_='foreignkey')
    op.drop_index('ix_users_team_id', table_name='users')
    op.drop_column('users', 'team_id')

    op.drop_table('teams')
