from telegram import ReplyKeyboardMarkup


def build_pending_menu() -> ReplyKeyboardMarkup:
    keyboard = [
        ["Помощь", "Профиль"],
    ]
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True)


def build_teacher_menu() -> ReplyKeyboardMarkup:
    keyboard = [
        ["Помощь", "Профиль"],
        ["Рассчитать отчёт", "Последний отчёт"],
        ["Меню преподавателя"],
    ]
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True)


def build_admin_menu() -> ReplyKeyboardMarkup:
    keyboard = [
        ["Помощь", "Профиль"],
        ["Рассчитать отчёт", "Последний отчёт"],
        ["Пользователи", "Привязать Telegram"],
        ["Меню преподавателя"],
    ]
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True)