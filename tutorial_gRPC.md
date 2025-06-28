# ⚡ gRPC Tutorial – DevOps Edition

## 🧠 Ce este gRPC?

**gRPC** este un protocol de comunicație între servicii, dezvoltat de Google. Este o alternativă modernă și performantă la API-urile REST clasice.

---

## 🔍 gRPC vs. REST

| Caracteristică     | REST (clasic)      | gRPC                          |
|--------------------|--------------------|-------------------------------|
| Protocol           | HTTP/1.1           | HTTP/2                        |
| Format date        | JSON               | Protocol Buffers (protobuf)  |
| Viteză             | Mai lent           | ⚡ Mult mai rapid              |
| Streaming          | Greu, cu WebSocket | ✅ Nativ (bidirectional)       |
| Tipare stricte     | Liber (flexibil)   | ✅ Contract strict (protos)    |
| Tooling DevOps     | curl, Postman      | grpcurl, grpcui, SDK-uri      |

---

## 🧪 Exemple

### 🔸 REST API

```http
POST /createUser
Content-Type: application/json

{
  "username": "petrisor",
  "email": "test@test.com"
}
```

### 🔸 gRPC (cu .proto)

```proto
service UserService {
  rpc CreateUser (UserRequest) returns (UserResponse);
}
```

Apoi apelul din cod (ex: Go):

```go
client.CreateUser(ctx, &UserRequest{
  Username: "petrisor",
  Email:    "test@test.com",
})
```

---

## 📦 De ce se folosește în microservicii?

- ✅ Rapid (HTTP/2 + binary compact)
- ✅ Eficient (trafic redus)
- ✅ Suportă streaming bidirecțional
- ✅ Contract fix între client și server (via .proto)
- ✅ Ideal pentru IoT și volume mari de date

---

## 👷 Ce trebuie să știe un DevOps?

| Context        | Ce trebuie să știi                                                                 |
|----------------|-------------------------------------------------------------------------------------|
| Kubernetes     | Ingress-ul trebuie să suporte HTTP/2 și gRPC                                       |
| NGINX Ingress  | Adaugă: `nginx.ingress.kubernetes.io/backend-protocol: "GRPC"`                    |
| Istio          | Suportă gRPC nativ, Envoy detectează automat gRPC                                  |
| Testare        | Folosește `grpcurl` pentru a testa serviciile (ca `curl` pentru gRPC)              |
| Observabilitate| Prometheus, Grafana și Istio pot măsura metrice pentru servicii gRPC               |

---

## 🧪 Testare rapidă cu `grpcurl`

```bash
# Listare servicii
grpcurl -plaintext my-service:50051 list

# Apel RPC
grpcurl -plaintext my-service:50051 my.Service/GetInfo
```

---

## 🧠 Concluzie

gRPC e alegerea potrivită dacă ai nevoie de:

- performanță ridicată
- trafic redus
- contract strict între servicii
- streaming bidirecțional în microservicii moderne
