FROM python:3.11-slim

WORKDIR /app

# Copy requirements.txt from current context (app folder)
COPY requirements.txt /app/

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy all app files from current context (app folder)
COPY . /app/

# Expose port
EXPOSE 8000

# Run the app
CMD ["python", "app.py"]