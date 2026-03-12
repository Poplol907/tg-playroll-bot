from telegram import ReplyKeyboardMarkup


def build_root_menu() -> ReplyKeyboardMarkup:
    keyboard = [
        ["Меню админа", "Меню преподавателя"],
        ["Профиль", "Помощь"],
    ]
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True)


def build_admin_menu() -> ReplyKeyboardMarkup:
    keyboard = [
        ["Пользователи", "Привязать Telegram"],
        ["Назначить роль", "Изменить логин"],
        ["Назад"],
    ]
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True)


def build_teacher_menu() -> ReplyKeyboardMarkup:
    keyboard = [
        ["Рассчитать отчёт", "Последний отчёт"],
        ["Мои отчёты"],
        ["Профиль", "Помощь"],
        ["Назад"],
    ]
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True)