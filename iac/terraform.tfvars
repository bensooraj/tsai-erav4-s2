# --- Required/commonly changed ---
region          = "us-east-1"
name            = "tsai-erav4-s2-fastapi"
instance_type   = "t3.micro"
github_repo_url = "https://github.com/bensooraj/tsai-erav4-s2.git"

# --- Optional: enable SSH access (comment out or set to "" to disable) ---
# Use your real public key and your public IP in CIDR form.
ssh_key_name = "fastapi-pkey"
# ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMockKeyGoesHere1234567890ABCDEFG your_email@example.com"
# ssh_cidr       = "203.0.113.10/32"
