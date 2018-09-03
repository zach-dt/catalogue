FROM scratch
EXPOSE 8080
ENTRYPOINT ["/sockshop-ws"]
COPY ./bin/ /