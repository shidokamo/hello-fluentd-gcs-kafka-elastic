IMAGE_REPOSITORY=gcr.io
GCP_PROJECT:= $(shell gcloud config get-value project)
PREFIX := ${IMAGE_REPOSITORY}/${GCP_PROJECT}
TEST_LOGGER_IMAGE := ${PREFIX}/test-logger:v2.0.0
FLUENTD_IMAGE := ${PREFIX}/fluentd:v1.7.0c
GCS_BUCKET := ${GCP_PROJECT}-aggregator
KEY_FILE := key.json
ELASTIC_HOST :=
include env
export

deploy:clean
	kubectl apply -f aggregator-fluentd-configmap.yaml
	cat aggregator-deployment.yaml | envsubst |  kubectl apply -f -
	kubectl apply -f aggregator-service.yaml
	kubectl apply -f forwarder-fluentd-configmap.yaml
	cat forwarder-deployment.yaml | envsubst | kubectl apply -f -
clean:
	-kubectl delete deployment forwarder
	-kubectl delete configmap forwarder-fluentd-config
	-kubectl delete deployment aggregator
	-kubectl delete service aggregator
	-kubectl delete configmap aggregator-fluentd-config

# Setups required once before deploying loggers
setup-cluster:
	gcloud container clusters create logging \
		--disk-size=100 \
		--machine-type=n1-standard-1 \
		--no-enable-cloud-logging \
		--no-enable-cloud-monitoring \
		--enable-stackdriver-kubernetes \
		--enable-autoscaling \
		--max-nodes=6
setup-helm:
	kubectl apply -f create-helm-service-account.yaml
	helm init --history-max 200 --service-account tiller
	helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
kafka:clean-kafka
	helm install --name kafka -f kafka-helm-values.yaml incubator/kafka
clean-kafka:
	-helm delete --purge kafka
clean-cluster:
	gcloud container clusters delete logging
clean-gcs:
	gsutil -m rm -r gs://${GCS_BUCKET}

# Keyfile for each pod
service-account:aggregator-service-account
aggregator-service-account:
	gcloud iam service-accounts keys create ${KEY_FILE} \
		--iam-account ${@}@${GCP_PROJECT}.iam.gserviceaccount.com
	-kubectl create secret generic ${@} --from-file=${KEY_FILE}
	rm ${KEY_FILE}

# Debug : Kafka endpoint
check-endpoint:
	kubectl describe svc kafka-0-external
# Debug : GCS
check-gcs:
	gsutil ls gs://${GCS_BUCKET}
