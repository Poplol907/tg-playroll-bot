from telegram import ReplyKeyboardMarkup


def build_root_menu() -> ReplyKeyboardMarkup:
    keyboard = [
        ["Меню админа", "Меню преподавателя"],
        ["Профиль", "Помощь"],
    ]
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True)


def build_admin_menu() -> ReplyKeyboardMarkup:
    keyboard = [
        ["Ученики", "Педагоги"],
        ["Инструменты", "Отчёты"],
        ["Пользователи", "Настройки"],
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


def build_students_menu() -> ReplyKeyboardMarkup:
    keyboard = [
        ["Список учеников", "Добавить ученика"],
        ["Назад в меню админа"],
    ]
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True)


def build_instruments_menu() -> ReplyKeyboardMarkup:
    keyboard = [
        ["Список инструментов", "Добавить инструмент"],
        ["Назад в меню админа"],
    ]
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True)


def build_reports_admin_menu() -> ReplyKeyboardMarkup:
    keyboard = [
        ["Зарплата педагога", "Статистика студии"],
        ["Назад в меню админа"],
    ]
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True)


def build_settings_menu() -> ReplyKeyboardMarkup:
    keyboard = [
        ["Установить пароль", "Список пользователей"],
        ["Привязать Telegram", "Назначить роль"],
        ["Изменить логин"],
        ["Назад в меню админа"],
    ]
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True)


def build_teachers_menu() -> ReplyKeyboardMarkup:
    keyboard = [
        ["Список педагогов"],
        ["Ставки педагогов"],
        ["Назад в меню админа"],
    ]
    return ReplyKeyboardMarkup(keyboard, resize_keyboard=True)
