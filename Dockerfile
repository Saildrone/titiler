FROM python:3.8.9-slim-buster

RUN set -ex \
    && mkdir /opt/titiler

WORKDIR /opt/titiler

# Install packages
COPY src/titiler/ /tmp/titiler/

RUN pip install /tmp/titiler/core /tmp/titiler/mosaic /tmp/titiler/application --no-cache-dir

RUN rm -rf /tmp/titiler

ENV MODULE_NAME titiler.application.main
ENV VARIABLE_NAME app

# expose port
EXPOSE 3000
# Metrics port
EXPOSE 9100

CMD ["start"]
