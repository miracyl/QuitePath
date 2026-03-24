from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup


class Registration(StatesGroup):
    waiting_for_jira_id = State()  # Состояние "ожидание ввода ID"
