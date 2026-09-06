  56  # Add the Bitnami repo
   57  helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
   58  # Install the controller into the 'kube-system' namespace of your MAIN cluster
   59  helm install sealed-secrets-controller sealed-secrets/sealed-secrets   --namespace kube-system   --set-string fullnameOverride=sealed-secrets-controller
   60  kubeseal --fetch-cert   --controller-name=sealed-secrets-controller   --controller-namespace=kube-system > main-cluster-public-key.pem
   61  KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
   62  curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
   63  tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
   64  sudo install -m 755 kubeseal /usr/local/bin/kubeseal
   65  kubeseal --fetch-cert   --controller-name=sealed-secrets-controller   --controller-namespace=kube-system > main-cluster-public-key.pem
   66  # 1. Create a local draft (don't commit this!)
   67  kubectl create secret generic my-db-secret   --from-literal=password=supersecret123   --dry-run=client -o yaml > my-secret.yaml
   68  # 2. Seal it using the certificate from Step A
   69  kubeseal --format yaml --cert main-cluster-public-key.pem < my-secret.yaml > templates/sealed-secret.yaml
   70  # 3. Delete the plain text file!
   71  rm my-secret.yaml
   72  kubectl create secret generic my-db-secret   --from-literal=password=supersecret123   --dry-run=client -o yaml > my-secret.yaml
   73  kubeseal --format yaml --cert main-cluster-public-key.pem < my-secret.yaml > sealed-secret.yaml