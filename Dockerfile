# syntax = docker/dockerfile:1

ARG BASE_IMAGE=026314688606.dkr.ecr.us-west-2.amazonaws.com/python:3.8

FROM ${BASE_IMAGE} AS runtime

ARG CODEARTIFACT_AUTH_TOKEN
ARG PIP_INDEX_URL="https://aws:${CODEARTIFACT_AUTH_TOKEN}@sd-package-repo-026314688606.d.codeartifact.us-west-2.amazonaws.com/pypi/sd-package-repo/simple/"

ENV PYTHONUNBUFFERED=1

WORKDIR /opt/titiler

# Install packages
COPY src/titiler/ /tmp/titiler/
COPY requirements.txt /opt/titiler

RUN <<ENDRUN
  set -e
  pip install rasterio==1.3.10 /tmp/titiler/core /tmp/titiler/mosaic /tmp/titiler/application --no-cache-dir --upgrade
  rm -rf /tmp/titiler
  pip install -r requirements.txt
ENDRUN

COPY app.sh .
COPY saildrone_custom_tiler ./saildrone_custom_tiler

# Copy over test data for local development
COPY test_mosaics ./test_mosaics/
COPY sample_data ./sample_data/

#ENV MODULE_NAME titiler.application.main
ENV MODULE_NAME=saildrone_custom_tiler.app.main
ENV VARIABLE_NAME=app

#ENV TITILER_MOSAIC_BACKEND s3://openvdm.dev.saildrone.com

# expose port
EXPOSE 3000
# Metrics port
EXPOSE 9100

#CMD ["uvicorn titiler.application.main:app"]
CMD ["/opt/titiler/app.sh"]
