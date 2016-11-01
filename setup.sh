#!/usr/bin/env bash
#
# Lambda Backup enable / disable script

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROVIDER="aws"

function usage {
    echo "Usage: AWS_DEFAULT_REGION=<your-aws-region> \\"
    echo "       AWS_ACCESS_KEY_ID=<your-access-key> \\"
    echo "       AWS_SECRET_ACCESS_KEY=<your-secret-key> \\"
    echo "       $0 <command>"
    echo "Command:"
    echo "  enable          Enable backups in your EC2 infrastructure."
    echo "                  This will create the necessary resources in"
    echo "                  AWS to schedule automatic EC2 snapshots"
    echo "                  overnight."
    echo ""
    echo "  disable         Disable backups and tear down the resources."
}

function ensure_terraform {
    local INSTALLED_TERRAFORM=$(which terraform)

    if [[ -x "$DIR/terraform/terraform" ]]; then
        TERRAFORM="$DIR/terraform/terraform"

    elif [[ ! -x "$INSTALLED_TERRAFORM" ]]; then
        case "$(uname -s)" in

            Darwin)
                echo "Terraform not found in PATH, downloading for OS X ..."
                if [[ "$(uname -m)" == "x86_64" ]]; then
                    TF_URL="https://releases.hashicorp.com/terraform/0.7.7/terraform_0.7.7_darwin_amd64.zip"
                else
                    TF_URL="https://releases.hashicorp.com/terraform/0.7.7/terraform_0.7.7_darwin_386.zip"
                fi
                
                ;;

            Linux)
                echo "Terraform not found in PATH, downloading for Linux ..."
                if [[ "$(uname -m)" == "x86_64" ]]; then
                    TF_URL="https://releases.hashicorp.com/terraform/0.7.7/terraform_0.7.7_linux_amd64.zip"
                else
                    TF_URL="https://releases.hashicorp.com/terraform/0.7.7/terraform_0.7.7_linux_386.zip"
                fi
                ;;

            *)
                echo "ERROR: Unfortunately Lambda Backup currently runs only on Linux or OS X, and you don't seem to be running either."
                exit 2
                ;;
        esac
        if [[ -x "$(which wget)" ]]; then
            wget -O $DIR/terraform.zip $TF_URL
        else
            curl -s $TF_URL > $DIR/terraform.zip
        fi
        unzip terraform.zip -d $DIR/terraform/
        rm terraform.zip
        TERRAFORM="$DIR/terraform/terraform"
    else
        TERRAFORM=$INSTALLED_TERRAFORM
    fi
}

function package_lambdafunction {
    echo -n "Packaging lambda function ... "
    rm -f $DIR/lib/$PROVIDER/dist/lambda-backup.zip
    mkdir -p $DIR/lib/$PROVIDER/dist
    cd $DIR/lib/$PROVIDER/src
    zip ../dist/lambda-backup.zip * > /dev/null
    cd $DIR
    echo "OK"
}

function randomize_backuptime {
    BACKUPHOUR=1
    BACKUPMINUTE=$((1 + RANDOM % 59))
    if [[ $BACKUPMINUTE -lt 10 ]]; then
        BACKUPMINUTE="0${BACKUPMINUTE}"
    fi
}

function ensure_credentials {
    if [ "${AWS_DEFAULT_REGION}" == "" ] || [ "${AWS_ACCESS_KEY_ID}" == "" ] || [ "${AWS_SECRET_ACCESS_KEY}" == "" ]; then
        echo "Error: AWS_DEFAULT_REGION, AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY not set"
        usage
        exit 2
    fi
}

echo -e "Lambda Backup\n"

case "$1" in
    enable)
        ensure_credentials
        ensure_terraform
        package_lambdafunction
        randomize_backuptime
        
        echo "Installing resources with Terraform ... "
        set -e
        $TERRAFORM apply -var "region=${AWS_DEFAULT_REGION}" -var "schedule_min=${BACKUPMINUTE}" -var "schedule_hour=${BACKUPHOUR}" $DIR/lib/$PROVIDER/

        echo -e "\n*** Finished. You should be able to see snapshots being created tonight at around ${BACKUPHOUR}:${BACKUPMINUTE} am."
        ;;

    disable)
        ensure_credentials
        ensure_terraform

        rm -f $DIR/dist/lambda-function.zip

        echo "Removing resources with Terraform ... "
        set -e
        $TERRAFORM destroy -force $DIR/lib/$PROVIDER/

        echo -e "\n*** Finished. Lambda Backup has been removed from your AWS account. Unexpired backup snapshots have been preserved."
        ;;

    *)
        usage
        exit 1
        ;;
esac
