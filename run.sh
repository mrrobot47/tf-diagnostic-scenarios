#!/bin/bash

# --- Helper Functions ---

# Function to print error messages
print_error() {
    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "[ERROR] $1"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo
}

# Function to print success messages
print_success() {
    echo "**************************************"
    echo "[SUCCESS] $1"
    echo "**************************************"
}

# Function to print info messages
print_info() {
    echo
    echo "--------------------------------------"
    echo "[INFO] $1"
    echo "--------------------------------------"
}

# --- Prerequisite and Configuration Functions ---

# Check for required command-line tools
check_dependencies() {
    print_info "Checking dependencies..."
    if ! command -v terraform > /dev/null 2>&1; then
        print_error "Terraform could not be found. Please install it first."
        exit 1
    fi
    if ! command -v gcloud > /dev/null 2>&1; then
        print_error "gcloud could not be found. Please install it first."
        exit 1
    fi
    print_success "All dependencies are installed."
}

# Load config from .env file, gcloud config, or prompt user
load_or_create_config() {
    if [ -f ".env" ]; then
        print_info "Loading configuration from .env file."
        set -a
        source .env
        set +a
    else
        print_info "No .env file found. Trying to get configuration from gcloud..."

        PROJECT_ID=""
        PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
        REGION=""
        REGION=$(gcloud config get-value compute/region 2>/dev/null)

        if [ -n "$PROJECT_ID" ]; then
            while true; do
                read -p "Auto-detected Project ID: ${PROJECT_ID}. Use this? (y/n): " -n 1 -r
                echo
                if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
                    break
                elif [ "$REPLY" = "n" ] || [ "$REPLY" = "N" ]; then
                    read -r -p "Enter your GCP Project ID: " PROJECT_ID
                    break
                else
                    echo "Please enter 'y' or 'n' only."
                fi
            done
        else
            print_info "Could not determine Project ID from gcloud config."
            read -r -p "Enter your GCP Project ID: " PROJECT_ID
        fi

        if [ -n "$REGION" ]; then
            while true; do
                read -p "Auto-detected Region: ${REGION}. Use this? (y/n): " -n 1 -r
                echo
                if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
                    break
                elif [ "$REPLY" = "n" ] || [ "$REPLY" = "N" ]; then
                    read -r -p "Enter the default GCP Region (e.g., us-central1): " REGION
                    if [ -z "$REGION" ]; then
                        REGION="us-central1"
                    fi
                    break
                else
                    echo "Please enter 'y' or 'n' only."
                fi
            done
        else
            print_info "Could not determine Region from gcloud config."
            read -r -p "Enter the default GCP Region (e.g., us-central1): " REGION
        fi

        if [ -z "$PROJECT_ID" ] || [ -z "$REGION" ]; then
            print_error "Project ID and Region are required. Exiting."
            exit 1
        fi

        echo "PROJECT_ID=${PROJECT_ID}" > .env
        echo "REGION=${REGION}" >> .env
        print_success "Configuration saved to .env file for future runs."
        export PROJECT_ID
        export REGION
    fi
}

# Check gcloud authentication status
check_gcloud_auth() {
    print_info "Checking gcloud authentication status..."
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "."; then
        print_error "You are not authenticated with gcloud. Please run 'gcloud auth login' and 'gcloud config set project <YOUR_PROJECT_ID>'."
        exit 1
    fi
    local active_account
    active_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    print_success "Authenticated with gcloud as: ${active_account}"
}

# --- Scenario and Terraform Functions ---

# Prompt for and save scenario-specific variables
get_scenario_vars() {
    local scenario_num=$1

    case $scenario_num in
        1)
            if [ -z "$USER_EMAIL" ]; then
                local gcloud_email
                gcloud_email=$(gcloud config get-value account 2>/dev/null)
                if [ -n "$gcloud_email" ]; then
                    while true; do
                        read -p "Auto-detected email: ${gcloud_email}. Use this? (y/n): " -n 1 -r
                        echo
                        if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
                            USER_EMAIL=$gcloud_email
                            break
                        elif [ "$REPLY" = "n" ] || [ "$REPLY" = "N" ]; then
                            read -r -p "Enter the User Email for Cloud Run access: " USER_EMAIL
                            break
                        else
                            echo "Please enter 'y' or 'n' only."
                        fi
                    done
                else
                    read -r -p "Enter the User Email for Cloud Run access: " USER_EMAIL
                fi
                echo "USER_EMAIL=${USER_EMAIL}" >> .env
                export USER_EMAIL
            fi
            ;;
        2)
            if [ -z "$ZONE" ]; then
                read -r -p "Enter the Zone for the GCE instance (e.g., us-central1-a): " ZONE
                if [ -z "$ZONE" ]; then
                    ZONE="${REGION}-a"
                fi
                echo "ZONE=${ZONE}" >> .env
                export ZONE
            fi
            if [ -z "$DOMAIN_NAME" ]; then
                read -r -p "Enter a domain name (e.g., example.com): " DOMAIN_NAME
                echo "DOMAIN_NAME=${DOMAIN_NAME}" >> .env
                export DOMAIN_NAME
            fi
            ;;
        4)
            if [ -z "$ZONE" ]; then
                read -r -p "Enter the Zone for the GCE instance (e.g., us-central1-a): " ZONE
                if [ -z "$ZONE" ]; then
                    ZONE="${REGION}-a"
                fi
                echo "ZONE=${ZONE}" >> .env
                export ZONE
            fi
            ;;
        8)
            if [ -z "$ZONE" ]; then
                read -r -p "Enter the Zone for the Filestore instance (e.g., us-central1-a): " ZONE
                if [ -z "$ZONE" ]; then
                    ZONE="${REGION}-a"
                fi
                echo "ZONE=${ZONE}" >> .env
                export ZONE
            fi
            ;;
        9)
            if [ -z "$OAUTH_SUPPORT_EMAIL" ]; then
                read -r -p "Enter the OAuth support email for IAP consent screen: " OAUTH_SUPPORT_EMAIL
                echo "OAUTH_SUPPORT_EMAIL=${OAUTH_SUPPORT_EMAIL}" >> .env
                export OAUTH_SUPPORT_EMAIL
            fi
            if [ -z "$IAP_MEMBERS" ]; then
                read -r -p "Enter IAP members (comma-separated, e.g. user:foo@bar.com,user:bar@baz.com): " IAP_MEMBERS
                echo "IAP_MEMBERS=${IAP_MEMBERS}" >> .env
                export IAP_MEMBERS
            fi
            if [ -z "$CREATE_OAUTH_CLIENT" ]; then
                while true; do
                    read -p "Should Terraform create the OAuth client? (y/n): " -n 1 -r
                    echo
                    if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
                        CREATE_OAUTH_CLIENT=true
                        break
                    elif [ "$REPLY" = "n" ] || [ "$REPLY" = "N" ]; then
                        CREATE_OAUTH_CLIENT=false
                        break
                    else
                        echo "Please enter 'y' or 'n' only."
                    fi
                done
                echo "CREATE_OAUTH_CLIENT=${CREATE_OAUTH_CLIENT}" >> .env
                export CREATE_OAUTH_CLIENT
            fi
            if [ "$CREATE_OAUTH_CLIENT" = false ]; then
                if [ -z "$EXISTING_OAUTH_CLIENT_ID" ]; then
                    read -r -p "Enter existing OAuth client ID: " EXISTING_OAUTH_CLIENT_ID
                    echo "EXISTING_OAUTH_CLIENT_ID=${EXISTING_OAUTH_CLIENT_ID}" >> .env
                    export EXISTING_OAUTH_CLIENT_ID
                fi
                if [ -z "$EXISTING_OAUTH_CLIENT_SECRET" ]; then
                    read -r -p "Enter existing OAuth client secret: " EXISTING_OAUTH_CLIENT_SECRET
                    echo "EXISTING_OAUTH_CLIENT_SECRET=${EXISTING_OAUTH_CLIENT_SECRET}" >> .env
                    export EXISTING_OAUTH_CLIENT_SECRET
                fi
            fi
            ;;
        10)
            if [ -z "$TEST_USER_EMAIL" ]; then
                read -r -p "Enter the test user email for Cloud Run access: " TEST_USER_EMAIL
                echo "TEST_USER_EMAIL=${TEST_USER_EMAIL}" >> .env
                export TEST_USER_EMAIL
            fi
            ;;
        11)
            if [ -z "$TEST_USER_EMAIL" ]; then
                read -r -p "Enter the test user email for Cloud Run access: " TEST_USER_EMAIL
                echo "TEST_USER_EMAIL=${TEST_USER_EMAIL}" >> .env
                export TEST_USER_EMAIL
            fi
            if [ -z "$GITHUB_REPO_OWNER" ]; then
                read -r -p "Enter the GitHub repo owner: " GITHUB_REPO_OWNER
                echo "GITHUB_REPO_OWNER=${GITHUB_REPO_OWNER}" >> .env
                export GITHUB_REPO_OWNER
            fi
            if [ -z "$GITHUB_REPO_NAME" ]; then
                read -r -p "Enter the GitHub repo name: " GITHUB_REPO_NAME
                echo "GITHUB_REPO_NAME=${GITHUB_REPO_NAME}" >> .env
                export GITHUB_REPO_NAME
            fi
            if [ -z "$GITHUB_BRANCH" ]; then
                read -r -p "Enter the GitHub branch name: " GITHUB_BRANCH
                echo "GITHUB_BRANCH=${GITHUB_BRANCH}" >> .env
                export GITHUB_BRANCH
            fi
            ;;
        12)
            if [ -z "$TEST_USER_EMAIL" ]; then
                read -r -p "Enter the test user email for Cloud Run access: " TEST_USER_EMAIL
                echo "TEST_USER_EMAIL=${TEST_USER_EMAIL}" >> .env
                export TEST_USER_EMAIL
            fi
            if [ -z "$USE_DEFAULT_NETWORK" ]; then
                while true; do
                    read -p "Use default network? (y/n, default n): " -n 1 -r
                    echo
                    if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
                        USE_DEFAULT_NETWORK=true
                        break
                    elif [ "$REPLY" = "n" ] || [ "$REPLY" = "N" ] || [ -z "$REPLY" ]; then
                        USE_DEFAULT_NETWORK=false
                        break
                    else
                        echo "Please enter 'y' or 'n' only."
                    fi
                done
                echo "USE_DEFAULT_NETWORK=${USE_DEFAULT_NETWORK}" >> .env
                export USE_DEFAULT_NETWORK
            fi
            if [ -z "$ENABLE_APIS_AUTOMATICALLY" ]; then
                while true; do
                    read -p "Enable APIs automatically? (y/n, default y): " -n 1 -r
                    echo
                    if [ "$REPLY" = "n" ] || [ "$REPLY" = "N" ]; then
                        ENABLE_APIS_AUTOMATICALLY=false
                        break
                    elif [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ] || [ -z "$REPLY" ]; then
                        ENABLE_APIS_AUTOMATICALLY=true
                        break
                    else
                        echo "Please enter 'y' or 'n' only."
                    fi
                done
                echo "ENABLE_APIS_AUTOMATICALLY=${ENABLE_APIS_AUTOMATICALLY}" >> .env
                export ENABLE_APIS_AUTOMATICALLY
            fi
            ;;
    esac
}

# Create terraform.tfvars file for a given scenario
create_tfvars() {
    local scenario_dir=$1
    local scenario_num=$2

    rm -f "${scenario_dir}/terraform.tfvars"

    echo "project_id = \"${PROJECT_ID}\"" > "${scenario_dir}/terraform.tfvars"
    echo "region     = \"${REGION}\"" >> "${scenario_dir}/terraform.tfvars"

    case $scenario_num in
        1)
            echo "user_email = \"${USER_EMAIL}\"" >> "${scenario_dir}/terraform.tfvars"
            ;;
        2)
            echo "zone        = \"${ZONE}\"" >> "${scenario_dir}/terraform.tfvars"
            echo "domain_name = \"${DOMAIN_NAME}\"" >> "${scenario_dir}/terraform.tfvars"
            ;;
        4)
            echo "zone = \"${ZONE}\"" >> "${scenario_dir}/terraform.tfvars"
            ;;
        8)
            echo "zone = \"${ZONE}\"" >> "${scenario_dir}/terraform.tfvars"
            ;;
        9)
            echo "oauth_support_email = \"${OAUTH_SUPPORT_EMAIL}\"" >> "${scenario_dir}/terraform.tfvars"
            # Convert comma-separated to quoted list
            IFS=',' read -ra MEMBERS_ARR <<< "$IAP_MEMBERS"
            echo -n "iap_members = [" >> "${scenario_dir}/terraform.tfvars"
            for i in "${!MEMBERS_ARR[@]}"; do
                m=$(echo "${MEMBERS_ARR[$i]}" | xargs)
                if [ $i -gt 0 ]; then echo -n ", " >> "${scenario_dir}/terraform.tfvars"; fi
                echo -n "\"$m\"" >> "${scenario_dir}/terraform.tfvars"
            done
            echo "]" >> "${scenario_dir}/terraform.tfvars"
            echo "create_oauth_client = ${CREATE_OAUTH_CLIENT}" >> "${scenario_dir}/terraform.tfvars"
            if [ "$CREATE_OAUTH_CLIENT" = false ]; then
                echo "existing_oauth_client_id     = \"${EXISTING_OAUTH_CLIENT_ID}\"" >> "${scenario_dir}/terraform.tfvars"
                echo "existing_oauth_client_secret = \"${EXISTING_OAUTH_CLIENT_SECRET}\"" >> "${scenario_dir}/terraform.tfvars"
            fi
            ;;
        10)
            echo "test_user_email = \"${TEST_USER_EMAIL}\"" >> "${scenario_dir}/terraform.tfvars"
            ;;
        11)
            echo "test_user_email = \"${TEST_USER_EMAIL}\"" >> "${scenario_dir}/terraform.tfvars"
            echo "github_repo_owner = \"${GITHUB_REPO_OWNER}\"" >> "${scenario_dir}/terraform.tfvars"
            echo "github_repo_name  = \"${GITHUB_REPO_NAME}\"" >> "${scenario_dir}/terraform.tfvars"
            echo "github_branch     = \"${GITHUB_BRANCH}\"" >> "${scenario_dir}/terraform.tfvars"
            ;;
        12)
            echo "test_user_email = \"${TEST_USER_EMAIL}\"" >> "${scenario_dir}/terraform.tfvars"
            echo "use_default_network = ${USE_DEFAULT_NETWORK}" >> "${scenario_dir}/terraform.tfvars"
            echo "enable_apis_automatically = ${ENABLE_APIS_AUTOMATICALLY}" >> "${scenario_dir}/terraform.tfvars"
            ;;
    esac
}

# Run a specific scenario
run_scenario() {
    local scenario_num=$1
    local destroy_mode=${2:-prompt} # prompt, auto, skip
    local scenario_dir
    scenario_dir=$(find diagnostic-scenarios -maxdepth 1 -type d -name "scenario-${scenario_num}-*" | head -n 1)

    if [ -z "$scenario_dir" ] || [ ! -d "$scenario_dir" ]; then
        print_error "Directory for scenario ${scenario_num} not found."
        return
    fi

    local scenario_name
    scenario_name=$(basename "$scenario_dir" | sed "s/scenario-${scenario_num}-//" | tr '-' ' ')
    # Capitalize first letter for older bash compatibility
    local first_char
    first_char=$(echo "$scenario_name" | cut -c1 | tr '[:lower:]' '[:upper:]')
    local rest_chars
    rest_chars=$(echo "$scenario_name" | cut -c2-)
    local capitalized_name="${first_char}${rest_chars}"

    print_info "Starting Scenario ${scenario_num}: ${capitalized_name}"

    get_scenario_vars "$scenario_num"
    create_tfvars "$scenario_dir" "$scenario_num"

    cd "$scenario_dir" || return

    print_info "Running 'terraform init'..."
    terraform init -upgrade >/dev/null

    print_info "Running 'terraform apply'..."
    local apply_log_file
    apply_log_file=$(mktemp)
    terraform apply -auto-approve 2>&1 | tee "$apply_log_file"
    local apply_exit_code=$?

    local apply_output
    apply_output=$(cat "$apply_log_file")
    rm "$apply_log_file"

    if [ $apply_exit_code -eq 0 ]; then
        print_success "Terraform apply completed successfully for Scenario ${scenario_num}."

        # Verification
        print_info "Performing verification..."
        case $scenario_num in
            1)
                local url
                url=$(terraform output -raw cloud_run_service_url)
                print_success "Cloud Run service deployed. URL: ${url}"
                ;;
            2)
                local ip
                ip=$(terraform output -raw load_balancer_ip)
                print_success "External Load Balancer created. IP: ${ip}"
                ;;
            3)
                local id
                id=$(terraform output -raw connector_id)
                print_success "VPC Connector created. ID: ${id}"
                ;;
            4)
                print_info "Waiting for Cloud NAT to be ready..."
                sleep 60
                print_info "Verifying scenario 4..."
                local cmd="gcloud compute instances get-serial-port-output test-sc-4-vm --zone=${ZONE} --project=${PROJECT_ID}"
                print_info "Running verification command: ${cmd}"
                if eval "$cmd" | grep -q "Hello from Google!"; then
                    print_success "Verified: Private VM has outbound internet access via Cloud NAT."
                else
                    print_error "Verification failed."
                fi
                ;;
            5)
                local url
                url=$(terraform output -raw service_url)
                print_success "Cloud Run + Cloud SQL deployed. Service URL: ${url}"
                local curl_cmd
                curl_cmd=$(terraform output -raw authenticated_curl_command)
                print_info "Test with: ${curl_cmd}"
                ;;
            6)
                local url
                url=$(terraform output -raw cloud_run_service_url)
                print_success "Cloud Run + Redis deployed. Service URL: ${url}"
                local curl_cmd
                curl_cmd=$(terraform output -raw authenticated_curl_command)
                print_info "Test with: ${curl_cmd}"
                ;;
            7)
                local url
                url=$(terraform output -raw cloud_run_service_url)
                print_success "Cloud Run + Vertex AI Vector Search deployed. Service URL: ${url}"
                local curl_cmd
                curl_cmd=$(terraform output -raw authenticated_curl_command)
                print_info "Test with: ${curl_cmd}"
                ;;
            8)
                local url
                url=$(terraform output -raw service_url)
                print_success "Cloud Run + Filestore deployed. Service URL: ${url}"
                local curl_cmd
                curl_cmd=$(terraform output -raw authenticated_curl_command)
                print_info "Test with: ${curl_cmd}"
                ;;
            *)
                print_success "Deployment successful (manual verification may be needed)."
                ;;
        esac

        if [ "$destroy_mode" = "auto" ]; then
            print_info "Running 'terraform destroy'..."
            terraform destroy -auto-approve
            print_success "Scenario ${scenario_num} resources destroyed."
        elif [ "$destroy_mode" = "skip" ]; then
            print_info "Resources are kept as per --no-destroy flag."
        else
            while true; do
                read -p "Do you want to destroy the resources now? (y/n) " -n 1 -r
                echo
                if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
                    print_info "Running 'terraform destroy'..."
                    terraform destroy -auto-approve
                    print_success "Scenario ${scenario_num} resources destroyed."
                    break
                elif [ "$REPLY" = "n" ] || [ "$REPLY" = "N" ]; then
                    break
                else
                    echo "Please enter 'y' or 'n' only."
                fi
            done
        fi
    else
        print_error "Terraform apply failed for Scenario ${scenario_num}."
        echo "--- Terraform Output ---"
        echo "${apply_output}"
        echo "------------------------"
        while true; do
            read -p "Do you want to run the cleanup script (cleanup.sh)? (y/n) " -n 1 -r
            echo
            if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
                if [ -f "cleanup.sh" ]; then
                    print_info "Running cleanup.sh..."
                    bash cleanup.sh
                else
                    print_error "cleanup.sh not found in this directory."
                fi
                break
            elif [ "$REPLY" = "n" ] || [ "$REPLY" = "N" ]; then
                break
            else
                echo "Please enter 'y' or 'n' only."
            fi
        done
    fi

    cd ../.. || exit # Return to root
}


# --- UI / Menus ---

# Display the main menu
main_menu() {
    while true; do
        echo
        echo "--- GCP Diagnostic Scenarios ---"
        echo "1. Scenario 1: Cloud Run + GCS"
        echo "2. Scenario 2: GCE + External LB"
        echo "3. Scenario 3: VPC Connector"
        echo "4. Scenario 4: Private GCE + Cloud NAT"
        echo "5. Scenario 5: Cloud Run + Cloud SQL"
        echo "6. Scenario 6: Cloud Run + Redis"
        echo "7. Scenario 7: Cloud Run + Vertex AI Vector Search"
        echo "8. Scenario 8: Cloud Run + Filestore"
        echo "9. Scenario 9: Cloud Run + IAP"
        echo "10. Scenario 10: Cloud Run Full State"
        echo "11. Scenario 11: Cloud Run Full State + Build"
        echo "12. Scenario 12: Cloud Run Agent Engine"
        echo "13. Destroy Resources Menu"
        echo "0. Exit"
        read -r -p "Select an option: " choice

        case $choice in
            1|2|3|4|5|6|7|8|9|10|11|12)
                run_scenario "$choice"
                ;;
            13)
                destroy_menu
                ;;
            0)
                break
                ;;
            *)
                print_error "Invalid option. Please try again."
                ;;
        esac
    done
}

# Display the destroy menu
destroy_menu() {
     while true; do
        echo
        echo "--- Destroy Resources ---"
        echo "1. Destroy Scenario 1"
        echo "2. Destroy Scenario 2"
        echo "3. Destroy Scenario 3"
        echo "4. Destroy Scenario 4"
        echo "5. Destroy Scenario 5"
        echo "6. Destroy Scenario 6"
        echo "7. Destroy Scenario 7"
        echo "8. Destroy Scenario 8"
        echo "9. Destroy Scenario 9"
        echo "10. Destroy Scenario 10"
        echo "11. Destroy Scenario 11"
        echo "12. Destroy Scenario 12"
        echo "0. Back to Main Menu"
        read -r -p "Select a scenario to destroy: " choice

        if [ "$choice" -ge 1 ] && [ "$choice" -le 12 ]; then
            local scenario_dir
            scenario_dir=$(find diagnostic-scenarios -maxdepth 1 -type d -name "scenario-${choice}-*" | head -n 1)
            if [ -n "$scenario_dir" ] && [ -d "$scenario_dir" ]; then
                print_info "Destroying resources for Scenario ${choice}..."
                cd "$scenario_dir" || return
                terraform destroy -auto-approve
                cd ../.. || exit
                print_success "Destroy operation finished for Scenario ${choice}."
            else
                print_error "Directory for scenario ${choice} not found."
            fi
        elif [ "$choice" -eq 0 ]; then
            break
        else
            print_error "Invalid option."
        fi
    done
}

# --- Main Execution ---
cd "$(dirname "$0")" || exit

# Argument parsing
usage() {
    echo "Usage: $0 [SCENARIO_NUMBER] [--destroy|--no-destroy]"
    echo "  SCENARIO_NUMBER: 1-12 (optional, if omitted, menu is shown)"
    echo "  --destroy: Destroys resources after successful deployment (optional)"
    echo "  --no-destroy: Keeps resources and skips destroy prompt (optional)"
    echo "  --destroy and --no-destroy are mutually exclusive."
    exit 0
}

# Show help before any checks
if [ $# -ge 1 ]; then
    case $1 in
        -h|--help|help)
            usage
            ;;
    esac
fi

check_dependencies
check_gcloud_auth
load_or_create_config

SCENARIO_NUM=""
DESTROY_MODE="prompt" # prompt, auto, skip

    if [ $# -ge 1 ]; then
        case $1 in
            [1-9]|1[0-2])
                SCENARIO_NUM="$1"
                ;;
            *)
                usage
                ;;
        esac
        if [ $# -ge 2 ]; then
            case $2 in            --destroy|destroy|DESTROY|--DESTROY)
                DESTROY_MODE="auto"
                ;;
            --no-destroy|no-destroy|NO-DESTROY|--NO-DESTROY)
                DESTROY_MODE="skip"
                ;;
            *)
                usage
                ;;
        esac
        if [ $# -ge 3 ]; then
            # Only one of --destroy or --no-destroy allowed
            usage
        fi
    fi
fi

if [ -n "$SCENARIO_NUM" ]; then
    run_scenario "$SCENARIO_NUM" "$DESTROY_MODE"
else
    main_menu
fi

print_info
