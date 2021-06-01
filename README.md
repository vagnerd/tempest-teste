# Desafio DevOps Tempest

## Desafio app docker (allowmedocker/devops-challenge)

Ao acessar o shell do o container através da função exec do comando docker, recebi as instruções sobre o teste:

#### Identificando a porta da aplicação

Foi utilizado o netstat para ver quais as portas estavam em estado de LISTEN dentro da micro virtulização do container

```
# netstat -anp
Active Internet connections (servers and established)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 :::1337                 :::*                    LISTEN      1/prova
Active UNIX domain sockets (servers and established)
Proto RefCnt Flags       Type       State         I-Node PID/Program name    Path
```

#### Conectando na porta da aplicação / Decodificando

A principio tentei utilizar o curl para acessar a aplicação porém o mesmo não estava instalado no container, identifiquei que a imagem usada era alpine e foi necessário através do gerenciador de pacotes instalar o curl:

```
# curl http://localhost:1337/
bash: curl: command not found
# curl http://localhost:1337/^C
# apk install curl^C
# apk add curl
fetch https://dl-cdn.alpinelinux.org/alpine/v3.13/main/x86_64/APKINDEX.tar.gz
fetch https://dl-cdn.alpinelinux.org/alpine/v3.13/community/x86_64/APKINDEX.tar.gz
(1/4) Installing brotli-libs (1.0.9-r3)
(2/4) Installing nghttp2-libs (1.42.0-r1)
(3/4) Installing libcurl (7.77.0-r0)
(4/4) Installing curl (7.77.0-r0)
Executing busybox-1.32.1-r3.trigger
OK: 10 MiB in 23 packages
# curl http://localhost:1337/
 ------------------
| DevOps Challenge |
 ------------------
Show! ;D Agora pegue o código que está na URI /code.
# curl http://localhost:1337/code
 ------------------
| DevOps Challenge |
 ------------------
Legal! o Código é NDIK
Ele está codificado de maneira simples, você precisa transformar ele em plaintext :D
Acesse /check/[coloque aqui o código que você descobriu]
# echo NDIK
NDIK
# echo NDIK | base64 -d
42
# curl http://localhost:1337/check/42
 ------------------
| DevOps Challenge |
 ------------------
Muito bem, você conseguiu :D e estamos felizes por isso :D
Agora acesse a URL /nicejob com o header X-OrigemDaVida: 42

#curl -H "X-OrigemDaVida: 42" http://localhost:1337/nicejob
```

Identifiquei que o código gerado estava em base64, e usei o comando já instalado na imagem para decodificar.

Também era possível acessar a aplicação através do nc (Netcat) não havendo a necessidade de instalar o curl:

```
# nc localhost 1337
GET /code HTTP/1.0

HTTP/1.0 200 OK
Date: Tue, 01 Jun 2021 00:38:40 GMT
Content-Length: 232
Content-Type: text/plain; charset=utf-8

 ------------------
| DevOps Challenge |
 ------------------
Legal! o Código é NDIK
Ele está codificado de maneira simples, você precisa transformar ele em plaintext :D
Acesse /check/[coloque aqui o código que você descobriu]
```

## Minikube e SampleApp

Conforme solicitado no exame, foi criado o seguinte Dockerfile:

```
FROM python

WORKDIR /app

RUN pip install flask

COPY . .

CMD [ "python", "./app.py" ]
```
O mesmo foi buildado e enviado para o dockerhub através dos seguintes comandos:
```
docker build . -t vagnerd/test-app:latest
docker push vagnerd/test-app:latest
```

Os yamls referentes aos recursos do kubernetes estão no diretório: *./kubernetes-resources/*

Para habilitar o uso do nginx-ingress no minikube foi executado o seguinte comando:

```
minikube addons enable ingress
```

## Monitoramento e Logs

Para instalar o prometheus e grafana com o Helm foi utilizado os seguintes comandos:

```
# Install and expose prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/prometheus
kubectl expose service prometheus-server --type=NodePort --target-port=9090 --name=prometheus-server-np
minikube service prometheus-server-np

# Install and expose grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana grafana/grafana
kubectl expose service grafana --type=NodePort --target-port=3000 --name=grafana-np
echo "GRAFANA TOKEN:"
kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
minikube service grafana-np
```

Para apresentar os logs na Kibana, foi necessário instalar o ES, Kibana e fluentbit:
```
# Install ES/KIBANA
helm repo add elastic https://helm.elastic.co
curl -O https://raw.githubusercontent.com/elastic/helm-charts/master/elasticsearch/examples/minikube/values.yaml
helm install elasticsearch elastic/elasticsearch -f ./values.yaml
kubectl expose service elasticsearch-master --type=NodePort --target-port=9200 --name=elasticsearch
helm install kibana elastic/kibana
kubectl expose service kibana-kibana --type=NodePort --target-port=5601 --name=kibana

# Install FLUENTD
helm repo add fluent https://fluent.github.io/helm-charts
helm install fluent-bit fluent/fluent-bit
``` 

Toda instalação pode ser feita através do script *./minikube-cluster/monitoramento.sh*

A instalação do minikube pode ser feita através do script *./minikube-cluster/install-minikube.sh*

## LOG (Resultados)
Os resultados estão disponiveis dentro do diretório *./log/*

*all-objects-k8s.txt* - Todos objetos criados no kubernetes (minikube) através do comando ```kubectl get all --all-namespaces```

*services-objects.txt* - Serviços listados com o comando ```minikube service list```

*Screenshots* - Screenshots com acesso as dashboards do Grafana e Kibana.

Acesso a dashboard do Grafana já com a datasource do Prometheus e uma dashboard importada (*log/dashboard-grafana.json*):
![Screenshot from 2021-05-31 20-51-00](https://user-images.githubusercontent.com/4332906/120252498-12505880-c25b-11eb-86f7-a6de5744e7fc.png)

Acesso a dashboard do Kibana já consumindo o ES e apresentando o log da aplicação:
![Screenshot from 2021-05-31 20-55-01](https://user-images.githubusercontent.com/4332906/120252499-12e8ef00-c25b-11eb-8dbf-ca02e17c5381.png)
![Screenshot from 2021-05-31 20-55-23](https://user-images.githubusercontent.com/4332906/120252501-13818580-c25b-11eb-808c-e106f1c7e904.png)


## Python Boto3

Não tenho conhecimentos profundos em python, optei pela linguagem por já conhecer e saber como funciona o componente boto3.

Para listar as instâncias é necessário instalar o componente através do pip e depois executar o script:

```
vagner@vagnerd:~/tempest/repo/tempest-teste/python-boto$ pip3 install -r requirements.txt 
Collecting boto3==1.17.84 (from -r requirements.txt (line 1))
  Using cached https://files.pythonhosted.org/packages/11/20/4294e37c3c6936c905f1e9da958c776d7fee54a4512bdb7706d69c8720e6/boto3-1.17.84-py2.py3-none-any.whl
Collecting jmespath<1.0.0,>=0.7.1 (from boto3==1.17.84->-r requirements.txt (line 1))
  Using cached https://files.pythonhosted.org/packages/07/cb/5f001272b6faeb23c1c9e0acc04d48eaaf5c862c17709d20e3469c6e0139/jmespath-0.10.0-py2.py3-none-any.whl
Collecting s3transfer<0.5.0,>=0.4.0 (from boto3==1.17.84->-r requirements.txt (line 1))
  Using cached https://files.pythonhosted.org/packages/63/d0/693477c688348654ddc21dcdce0817653a294aa43f41771084c25e7ff9c7/s3transfer-0.4.2-py2.py3-none-any.whl
Collecting botocore<1.21.0,>=1.20.84 (from boto3==1.17.84->-r requirements.txt (line 1))
  Using cached https://files.pythonhosted.org/packages/bc/22/72c81d754bbcb128cba2ad88670c3c320e4594e6ddd8cca6512c3967108c/botocore-1.20.84-py2.py3-none-any.whl
Collecting urllib3<1.27,>=1.25.4 (from botocore<1.21.0,>=1.20.84->boto3==1.17.84->-r requirements.txt (line 1))
  Using cached https://files.pythonhosted.org/packages/0c/cd/1e2ec680ec7b09846dc6e605f5a7709dfb9d7128e51a026e7154e18a234e/urllib3-1.26.5-py2.py3-none-any.whl
Collecting python-dateutil<3.0.0,>=2.1 (from botocore<1.21.0,>=1.20.84->boto3==1.17.84->-r requirements.txt (line 1))
  Using cached https://files.pythonhosted.org/packages/d4/70/d60450c3dd48ef87586924207ae8907090de0b306af2bce5d134d78615cb/python_dateutil-2.8.1-py2.py3-none-any.whl
Collecting six>=1.5 (from python-dateutil<3.0.0,>=2.1->botocore<1.21.0,>=1.20.84->boto3==1.17.84->-r requirements.txt (line 1))
  Using cached https://files.pythonhosted.org/packages/d9/5a/e7c31adbe875f2abbb91bd84cf2dc52d792b5a01506781dbcf25c91daf11/six-1.16.0-py2.py3-none-any.whl
Installing collected packages: jmespath, urllib3, six, python-dateutil, botocore, s3transfer, boto3
Successfully installed boto3-1.17.84 botocore-1.20.84 jmespath-0.9.5 python-dateutil-2.8.1 s3transfer-0.4.2 six-1.16.0 urllib3-1.25.9
You are using pip version 8.1.1, however version 21.1.2 is available.
You should consider upgrading via the 'pip install --upgrade pip' command.
vagner@vagnerd:~/tempest/repo/tempest-teste/python-boto$ ./list-ec2.py 
i-057d3a0e198b2a1de m5a.large
i-099d9fc323c25c2cd t3.small
i-0aec147884d091128 m5a.large
i-078b62a1937e4ef00 m5a.large
i-0628df9196265be45 m5a.large
i-01ee983c9b7ccbed6 m5a.large
```

Usado a seguinte documentação como referência:
https://boto3.amazonaws.com/v1/documentation/api/latest/guide/migrationec2.html
