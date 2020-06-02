# Deploy php application to kubernetes using bitbucket pipelines


###Setup docker registry access for kubernetes to pull image from private repo

1) Login to docker hub with username and password:
    
    ```docker login```

   It will generate a file that holds the authentication token
   
    ```cat ~/.docker/config.json```
    
   Output is similar to:
   
         {
             "auths": {
                 "https://index.docker.io/v1/": {
                     "auth": "*******"
                 }
             }
         }

2) Create a secret

        kubectl create secret generic dock-reg-cred     --from-file=.dockerconfigjson=~/.docker/config.json     --type=kubernetes.io/dockerconfigjson

    **Note:** this will create a secret named **dock-reg-cred** which can be consumed by any pod in the cluster securely.

3) Assign the secret to the php deployment

            spec:
              imagePullSecrets:
                - name: docker-reg-cred


### Set up a pipeline with the BitBucket
   
   
1) Docker file
   
    [Dockerfile](Dockerfile)
        
    The below will build a docker image using [php:7.2-fpm](https://hub.docker.com/_/php) as the base image.
    Also a php file to represent the successful run of the pipelines and it being deployed successfully to the kube cluster.
         
        FROM php:7.2-fpm
        
        ARG commit_hash
        
        RUN mkdir -p /build-code && echo "<?php echo 'Deployed using bitbucket pipelines. $commit_hash' ?>'" > /build-code/index.php
        
        WORKDIR /var/www

2) Pipeline build and deploy

      Build step to build an image and push it to the docker registry.

        - step:
            name: Build
            script:
              # generate docker image name
              - export IMAGE_NAME=$DOCKER_USERNAME/$BITBUCKET_REPO_SLUG:$BITBUCKET_COMMIT
              # build the Docker image
              - docker build -t $IMAGE_NAME . --build-arg commit_hash=$BITBUCKET_COMMIT
              # authenticate with the Docker Hub registry
              - docker login --username $DOCKER_USERNAME --password $DOCKER_PASSWORD
              # push the new Docker image to the Docker registry
              - docker push $IMAGE_NAME
            services:
              - docker
            caches:
              - docker
              
      Deploy the image to a kube cluster running on a remote server.        
              
        - step:
            name: Deploy
            deployment: testing
            script:
              - pipe: atlassian/ssh-run:0.2.5
                variables:
                  SSH_USER: $SSH_USER
                  SERVER: $SERVER_ADDRESS
                  PORT: $PORT
                  #COMMAND: 'kubectl set image deployment/php php=$DOCKER_USERNAME/$BITBUCKET_REPO_SLUG:$BITBUCKET_COMMIT'
                  COMMAND: 'sed  "s|{{image}}|$DOCKER_USERNAME/$BITBUCKET_REPO_SLUG:$BITBUCKET_COMMIT|g" ~/php-app/php_deployment.yaml | kubectl apply -f  -'
 


WIN!

References:

1) [Configure bitbucket pipelines](https://confluence.atlassian.com/bitbucket/configure-bitbucket-pipelines-yml-792298910.html)
2) [Bitbucket ssh-run](https://bitbucket.org/atlassian/ssh-run)