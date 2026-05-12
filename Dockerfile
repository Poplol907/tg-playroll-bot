FROM python:3.12-slim

WORKDIR /app

# Зависимости устанавливаем отдельным слоем — кешируется если requirements не менялся
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Исходники
COPY . .

# Папка для статики (IPA / APK / plist) — создаём заранее
RUN mkdir -p /app/static

EXPOSE 8000

# 2 воркера — достаточно для небольшой студии (10-50 пользователей)
CMD ["uvicorn", "backend.app.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "2"]
