#!/bin/bash
ssh -f -N -L 3000:localhost:30080 swcampus@172.30.1.83
ssh -f -N -L 8080:localhost:30081 swcampus@172.30.1.83
ssh -f -N -L 3001:localhost:3001 swcampus@172.30.1.83
ssh -f -N -L 8081:localhost:8081 swcampus@172.30.1.83
echo "SSH 터널링이 시작되었습니다."
echo "Client: http://localhost:3000"
echo "Server: http://localhost:8080"
echo "Grafana: http://localhost:3001"
echo "ArgoCD: https://localhost:8081"
