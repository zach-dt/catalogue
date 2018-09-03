FROM scratch
EXPOSE 8080
ENTRYPOINT ["/catalogue"]
COPY ./bin/ /