### VM Configuration.
1. Machine Config:
    1. Name: airflow-server
    2. Region: us-central1 (Iowa)
    3. Zone: us-central1a
    4. E2

2. OS and Storage:
    1. change os image to: ubuntu
    2. Version: Ubuntu 20.04 LTS
    3. Size: 30 GB

3. Network:
    1. Allow HTTP Traffic
    2. Allow HTTPS Traffic


### Firewall configuration

1. Name: airflow-ip-access
2. Target Tags: airflow-ip-access
3. TCP: 8080
Create

### Attaching tag to VM

1. attach firewall tag to vm by editing vm and attach usings tags.
