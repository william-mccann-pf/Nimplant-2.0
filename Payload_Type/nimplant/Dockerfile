# pull in the appropriate language's payload container from itsafeaturemythic on dockerhub
FROM python:3.8-slim-buster

# Update APT
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y apt-transport-https gpg git wget unzip mingw-w64

# Configure Mythic Packages
RUN pip install aio_pika requests mythic-payloadtype-container==0.0.44 dynaconf==3.1.4

# Configure Nim Packages
RUN apt-get update && apt-get install -y curl xz-utils g++ git 
RUN curl https://nim-lang.org/choosenim/init.sh -sSf | bash -s -- -y
ENV PATH=/root/.nimble/bin:$PATH

ENTRYPOINT ["/Mythic/mythic/payload_service.sh"]
