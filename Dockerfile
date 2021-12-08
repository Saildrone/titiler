FROM python:3.8.9-slim-buster

RUN set -ex \
    && mkdir /opt/titiler

WORKDIR /opt/titiler

# Install packages
COPY src/titiler/ /tmp/titiler/

RUN pip install uvicorn
RUN pip install aiocache

RUN pip install /tmp/titiler/core /tmp/titiler/mosaic /tmp/titiler/application --no-cache-dir

RUN rm -rf /tmp/titiler

COPY app.sh /opt/titiler
COPY saildrone_custom_tiler /opt/titiler/saildrone_custom_tiler

COPY bathy_daily_test_mosaic.json /opt/titiler
COPY dev_daily_product_mosaic.json /opt/titiler

#ENV MODULE_NAME titiler.application.main
ENV MODULE_NAME saildrone_custom_tiler
ENV VARIABLE_NAME app

# expose port
EXPOSE 3000
# Metrics port
EXPOSE 9100

#CMD ["uvicorn titiler.application.main:app"]
CMD ["/opt/titiler/app.sh"]
