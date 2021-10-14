FROM nimlang/nim:regular

RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get install python3.8 python3.8-dev python3.8-distutils python3.8-venv -y

RUN apt-get install mingw-w64 -y

# Configure Mythic Packages
RUN pip install aio_pika requests mythic-payloadtype-container==0.0.44 dynaconf==3.1.4

ENTRYPOINT ["/Mythic/mythic/payload_service.sh"]