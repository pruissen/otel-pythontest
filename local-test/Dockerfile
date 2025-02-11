FROM public.ecr.aws/lambda/python:3.10


COPY . ${LAMBDA_TASK_ROOT}


WORKDIR ${LAMBDA_TASK_ROOT}  
RUN yum update -y && yum install -y git && rm -Rf /var/cache/yum
RUN  pip3 install -r requirements.txt --target "${LAMBDA_TASK_ROOT}"

#TELEMETRY
COPY ./python_telemetry.tar.gz /opt/python_telemetry.tar.gz
WORKDIR /opt/
# Instalar tar y gzip
RUN yum update -y && \
    yum install -y tar gzip
RUN tar -xvzf python_telemetry.tar.gz
RUN  pip3 install -r ./python/requirements.txt --target "${LAMBDA_TASK_ROOT}"
##TELEMETRY

WORKDIR ${LAMBDA_TASK_ROOT}  


CMD ["lambda_function.lambda_handler" ]