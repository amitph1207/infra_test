vault


root key -> never stored -> multiple shards construct the root key

vaults starts -> gets pieces of keys from multiple shards -> construct the root key -> uses it to decrypt the encryption key ->  sss algorithm

now this encryption key is used to encrypt and decrypt the data

So if a random dude comes and takes away your storage, even though there is an encryption key on the storage he wont be able to decrypt it because the main boss aka root key is never stored anywhere and generated on the fly when vault starts in memory.


vault operator init --help
vault operator init -key-shares=1 -key-threshold=1
vault operator unseal
vault login
vault status
vault secrets enable -version=2 -path=secret kv
vault kv put -mount=secret my-secret foo=bar
vault kv get secret/my-secret



openbow
same as vault

ESO external secrets operator 

works along with vault, use ESO to fetch the secrets from vault, convert it into k8s secret form and put it in a cluster
sops + age

if you use argo cd to deploy applications in your cluster, you might be also having secret.yaml somewhere in the folder
you can not store them in github because anyone can read it so what you can instead do is use sops + age mechanism where you take the secret, encrypt it using age key and store secret_enc.yaml on the github

then you can add a secret in argo cd via patch or something to provide an encryption key to the argo cd server. when it will create an application and sync it from the github, it will convert secret_enc.yaml -> secret.yaml and put it in the cluster.

github actions

store secrets on github in an encrypted manner and put it inside a k8s cluster using kubeconfig
sealed secrets
run sealed-secrets-operator into the cluster
on github store sealed-secrets.yaml, a crd which is understood by sealed-secrets-operator
argocd syncs the custom sealed-secrets crd, operator converts it into a regular secret which is understood by an application
encryption at rest configuration
What if somebody gets access to an etcd disk? how do we make sure the data is not stored in plaintext on the disk? we can give apiserver a key which it will use to encrypt/decrypt secret before storing them on the disk

The challenge is how do we keep the main encryption key safe? again we will need a vault or something to make that happen.
sidecar injector or CSI plugin
The best solution is when you completely remove the k8s secret object from the picture. We store the secrets in the vault and then we add annotation on the pod which will invoke the sidecar injector running inside the pod to go and talk to the external vault, fetch the secret and put it inside the pod filesystem.

KMS - key management system

mtls

cert verification flow:

browser -> google.com/amazon.com

amazon.com -> presents it is certificate -> hey i am amazon.com

browser -> validate whether this is correct or not?

browser preinstalled public CA keys
issuer from the amazon.com
digitcert, lets encrypt, ca 
decrypt the digital signature on the certificate -> value1
calculate the hash of the entire certificate using the algo -> value2
value1 == value2
common name, expiry, other things 
6 && 7 are true, you are really an amazon.com


symmetric key + Diffie hellman

symmetric key encryption, same key for both encryption + decryption

how do 2 people who have never met with each other share a common secret which can be used for both encryption and decryption?

diffie-hellman key exchange algorithm:
 a ^ b mod c

first we need to agree on a and c

then both pirates pick their private b and d

assume a = 3  c = 17

alice => b = 15 => calculates 3 ^ 15 mod 17 = 6
bob =>  d = 13 => calculates 3 ^ 13 mod 17 = 12

now the trick

alice will take bob’s result -> 12 ^ 15 mod 17 -> 3 ^ 13 ^ 15 mod 17 -> x 
bob will alice’s result -> 6 ^ 13 mode 17 -> 3 ^ 15 ^ 13 mod 17  -> y

x and y both are same now

forward secrecy
somebody can look at my exchange with the server where i am using diffie-hellman shared secret

later on they find out server’s private key and get all the data of our communication

to avoid this “record now, decrypt later” thread we get fresh new dh in every session.
pki

public key + private key

public key is shared with everyone

when you want to use it to prove your identity -> you can sign your message with your private key -> outside world can take your public key -> decrypt it -> if they are able to do show then we can confirm that the message has indeed come from you

now the challenge is how do we generate such public key + private key pair
the math is similar to modular arithmetic but it does rely on prime factorization  + euler’s algo

RSA encryption 

========

when someone wants to send you a message, then can encrypt the message using your public key but only you can decrypt because you have the private key


pgp
so lets say we have rsa public key + private key 

alice bob
alice wants to send something to the bob
alice creates one session key, encrypts the message with session key, 
encrypts the session key with bob's public key -> sends it to bob

bob -> receives the message -> decrypts session key using the bob's private key -> gets the session key -> uses that to decrypt the message

the problem was directly using rsa to encrypt/decrypt large messages

gpg
just the open source implementation of pgp


ACME protocol
if you read the mtls section there is essentially a transaction between the server and CA. server needs to generate a public key + private key pair, generate a csr, send it to CA, CA does a bunch of verification and then sign the csr with ca’s private key

there is crl/ocsp process for cert revocation
there is also a cert renewal process

overall if you see there is a lot of manual overhead

ACME stands for Automated Certificate Management Environment and essentially automates everything that is mentioned above.

there are 2 main challenges - http-01 and dns-01 where it basically will ask you to do two things to make sure that you really own example.com

if you do that it will give you the certificate
lets encrypt
this is a product which implemented ACME and is non-profit from 2015. before let’s encrypt this thing used to cost money
lets encrypt made it free for everyone
cert-manager
k8s native implementation which watches out for the certs and resources and sees how things are 

if someone needs a cert or cert is about to expire, it essentially calls a pki 
the pki could be
lets encrypt
hashicorp vault
private pki

spiffe, spire
in datacenter your workload will interact with bunch of components, for example vault, external cloud service, s3 backup, kube api server etc etc

how do you provide an identity to your workload which can work across multiple places?

spiffe - global standard
spire - implementation of spiffe

spire agent on node -> bootstrap -> use kubelet cred to attest the node to the spire server running on the control plane

workload -> talks to spire agent socket -> asks for an identity -> gets x509 svid in return

automatic rotation and all the handling around it

workload1 can do mtls with workload2, with vault, with any other service in the data center…
