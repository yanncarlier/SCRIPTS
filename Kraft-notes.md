

https://unikraft.org/docs/

curl -sSfL https://get.kraftkit.sh | sh  



kraft run unikraft.org/helloworld:latest  

kraft run -p 8080:80 unikraft.org/nginx:latest  

kraft run .

kraft ps --all

kraft logs <instance-id-or-name>

kraft stop <instance-id-or-name>

kraft rm <instance-id-or-name>

kraft pkg ls --update --apps



Here is an example compose.yaml file:

```
version: '3.8'

services:
  app:
    # Points to a folder with a Kraftfile/Dockerfile combo
    build: ./my-app-folder
    ports:
      - "8080:8080"
    environment:
      - DB_HOST=database
    depends_on:
      - database

  database:
    # Pulls a pre-built isolated microVM from the Unikraft catalog
    image: unikraft.org/redis:latest
    ports:
      - "6379:6379"

```

kraft compose up -d  

kraft compose logs  

kraft compose down  