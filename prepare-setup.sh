# [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
# chmod +x ./kind
# sudo mv ./kind /usr/local/bin/kind

# kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml

export VERSION=$(curl -s https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)
echo $VERSION
kubectl create -f "https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml"

kubectl create -f "https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-cr.yaml"
kubectl apply -f https://raw.githubusercontent.com/kubevirt-manager/kubevirt-manager/main/kubernetes/bundled.yaml

export TAG=$(curl -s -w %{redirect_url} https://github.com/kubevirt/containerized-data-importer/releases/latest)
export VERSION=$(echo ${TAG##*/})
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-operator.yaml
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-cr.yaml

kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release-full.yaml

kubectl apply -f https://api.hub.tekton.dev/v1/resource/tekton/task/git-clone/0.9/raw

kubectl apply -f ingress-kubevirt.yml -f ingress-tekton.yml -f rbac.yml
kubectl apply -f task-image-build.yml -f task-image-sign.yml -f task-bootc-image-builder.yml -f task-kubevirt-vm.yml -f task-kubevirt-image.yml
kubectl apply -f pipeline-bootc-image-builder.yml -f pipeline-deploy-vm.yml -f pipeline-image-build.yml

kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml

helm upgrade --install --version=0.7.1 \
    --namespace $FC_NAMESPACE --create-namespace \
    flightctl ./deploy/helm/flightctl/ \
    --set global.exposeServicesMethod=nodePort \
    --set kv.fsGroup=1001 \
    --set db.fsGroup=26 \
    --set keycloak.db.fsGroup=26 \
    --set global.nodePorts.api=32001 \
    --set global.nodePorts.cliArtifacts=32002 \
    --set global.nodePorts.agent=32003 \
    --set global.nodePorts.ui=32004 \
    --set global.nodePorts.keycloak=32005 \
    --set "global.baseDomain=192.168.200.71.nip.io"

helm upgrade --install gitea gitea-charts/gitea \
-n gitea \
--set postgresql-ha.enabled=false \
--set postgresql.enabled=true \
--set gitea.admin.username="gitea" \
--set gitea.admin.password="redhat" \
--set gitea.config.webhook.ALLOWED_HOST_LIST="*" \
--set gitea.config.webhook.SKIP_TLS_VERIFY=true \
--set gitea.config.server.ROOT_URL=gitea.ui:31080 \
--set ingress.enabled=true \
--set "ingress.hosts[0].host=gitea.ui" \
--set "ingress.hosts[0].paths[0].path=/" \
--set "ingress.hosts[0].paths[0].pathType=Prefix"


auth_token=$(curl -k -s -X POST  -u "gitea:redhat" http://gitea.ui:31080/api/v1/users/gitea/tokens -H "Content-Type: application/json" -d '{"name": "Gitea token", "scopes": ["write:repository", "write:user"]}' | jq -r '.sha1')

curl -k -X POST http://gitea.ui:31080/api/v1/repos/migrate \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $auth_token" \
  -d '{"clone_addr": "https://github.com/kubealex/kind-fun.git", "repo_name": "devconf.cz-bootc"}'


curl -k -X POST \
  http://gitea.ui:31080/api/v1/repos/gitea/devconf.cz-bootc-keynote/hooks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $auth_token" \
  -d '{
    "type": "gitea",
    "active": true,
    "events": ["create"],
    "config": {
      "content_type": "json",
      "url": "http://el-image-build-listener.default:8080",
      "http_method": "POST"
    }
  }'