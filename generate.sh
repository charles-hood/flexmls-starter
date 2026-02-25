#!/bin/bash
#
# FlexMLS Starter - Site Generator
# Generates a complete static real estate site from the template.
#
# Usage: ./generate.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Find script directory (where templates live)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"
DEFAULTS_DIR="$SCRIPT_DIR/defaults"

echo ""
echo -e "${BOLD}${CYAN}=========================================${NC}"
echo -e "${BOLD}${CYAN}  FlexMLS Starter - Site Generator${NC}"
echo -e "${BOLD}${CYAN}=========================================${NC}"
echo ""
echo -e "This script generates a complete real estate website"
echo -e "with FlexMLS property listings. Just answer the prompts."
echo ""

# ─────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────

prompt() {
    local var_name="$1"
    local prompt_text="$2"
    local default_val="$3"
    local result

    if [ -n "$default_val" ]; then
        echo -ne "${YELLOW}${prompt_text}${NC} [${default_val}]: "
    else
        echo -ne "${YELLOW}${prompt_text}${NC}: "
    fi
    read -r result
    if [ -z "$result" ] && [ -n "$default_val" ]; then
        result="$default_val"
    fi
    eval "$var_name=\"\$result\""
}

prompt_required() {
    local var_name="$1"
    local prompt_text="$2"
    local result=""

    while [ -z "$result" ]; do
        echo -ne "${YELLOW}${prompt_text}${NC}: "
        read -r result
        if [ -z "$result" ]; then
            echo -e "${RED}  This field is required.${NC}"
        fi
    done
    eval "$var_name=\"\$result\""
}

url_encode() {
    python3 -c "import urllib.parse; print(urllib.parse.quote('$1'))"
}

slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g'
}

# ─────────────────────────────────────────
# Step 1: Output directory
# ─────────────────────────────────────────

echo -e "${BOLD}${GREEN}--- Output Directory ---${NC}"
prompt OUTPUT_DIR "Where should the site be generated?" "./my-realtor-site"
echo ""

if [ -d "$OUTPUT_DIR" ]; then
    echo -e "${RED}Directory '$OUTPUT_DIR' already exists.${NC}"
    echo -ne "${YELLOW}Overwrite? (y/n)${NC}: "
    read -r overwrite
    if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
        echo -e "${RED}Aborted.${NC}"
        exit 1
    fi
    rm -rf "$OUTPUT_DIR"
fi

# ─────────────────────────────────────────
# Step 2: Company info
# ─────────────────────────────────────────

echo -e "${BOLD}${GREEN}--- Company Information ---${NC}"
prompt_required COMPANY_NAME "Company name (e.g. Acme Realty)"
prompt COMPANY_SHORT_NAME "Short name for PWA (e.g. Acme)" "$(echo "$COMPANY_NAME" | awk '{print $1}')"
prompt_required COMPANY_CITY "City (e.g. Chattanooga)"
prompt_required COMPANY_STATE "State abbreviation (e.g. TN)"
prompt_required COMPANY_PHONE "Phone number (e.g. 423-555-1234)"
prompt_required COMPANY_EMAIL "Email address"
prompt_required COMPANY_ADDRESS "Full street address (e.g. 123 Main St, Chattanooga, TN 37402)"
echo ""

# Auto-derive raw phone (strip non-digits, prepend 1 if 10 digits)
COMPANY_PHONE_RAW=$(echo "$COMPANY_PHONE" | tr -d -c '0-9')
if [ ${#COMPANY_PHONE_RAW} -eq 10 ]; then
    COMPANY_PHONE_RAW="1${COMPANY_PHONE_RAW}"
fi

# Auto-derive URL-encoded address
COMPANY_ADDRESS_QUERY=$(url_encode "$COMPANY_ADDRESS")

# ─────────────────────────────────────────
# Step 3: Mission statement
# ─────────────────────────────────────────

DEFAULT_MISSION="For every customer, our agents work tirelessly to help them achieve their dreams. Our goal is to make buying and selling real estate as cost-effective as possible while providing the highest level of service."

echo -e "${BOLD}${GREEN}--- Mission Statement ---${NC}"
echo -e "  Press Enter to use the default, or type your own."
echo -e "  Default: \"${DEFAULT_MISSION:0:70}...\""
prompt COMPANY_MISSION "Mission statement" "$DEFAULT_MISSION"
echo ""

# ─────────────────────────────────────────
# Step 4: FlexMLS ID
# ─────────────────────────────────────────

echo -e "${BOLD}${GREEN}--- FlexMLS Configuration ---${NC}"
echo -e "  Your FlexMLS ID is in your FlexMLS dashboard URL."
echo -e "  Example: my.flexmls.com/${BOLD}YourCompanyID${NC}/search/..."
prompt_required FLEXMLS_ID "FlexMLS ID"
echo ""

# ─────────────────────────────────────────
# Step 5: Branding
# ─────────────────────────────────────────

echo -e "${BOLD}${GREEN}--- Branding ---${NC}"
prompt ACCENT_COLOR "Accent color (hex)" "#FFD700"

echo ""
echo -e "  Provide paths to your image files, or press Enter to skip."
echo -e "  Skipped images will use generic defaults."
prompt LOGO_PATH "Path to logo image (banner format, ~800x150)"
prompt OG_IMAGE_PATH "Path to social media / OG image"
prompt COMPANY_PHOTO_PATH "Path to company photo (for About modal)"
echo ""

# ─────────────────────────────────────────
# Step 6: Domain
# ─────────────────────────────────────────

echo -e "${BOLD}${GREEN}--- Domain (optional) ---${NC}"
echo -e "  Used for OG meta tags. Enter without https://."
prompt COMPANY_DOMAIN "Domain (e.g. acmerealty.com)" "example.com"
echo ""

# ─────────────────────────────────────────
# Step 7: Agents
# ─────────────────────────────────────────

echo -e "${BOLD}${GREEN}--- Agent Directory ---${NC}"
echo -e "  ${BOLD}1)${NC} Add agents interactively"
echo -e "  ${BOLD}2)${NC} Import from CSV file"
echo -e "  ${BOLD}3)${NC} Skip (add agents later by editing index.html)"
echo ""
echo -ne "${YELLOW}Choose (1/2/3)${NC} [3]: "
read -r agent_choice
agent_choice="${agent_choice:-3}"

AGENTS_JS=""
AGENT_FILES=()

case "$agent_choice" in
    1)
        # Interactive agent entry
        agent_count=0
        add_more="y"
        while [ "$add_more" = "y" ] || [ "$add_more" = "Y" ]; do
            agent_count=$((agent_count + 1))
            echo ""
            echo -e "${CYAN}  --- Agent #${agent_count} ---${NC}"
            prompt_required AGENT_NAME "  Name"
            prompt_required AGENT_EMAIL "  Email"
            prompt_required AGENT_PHONE "  Phone"
            echo -ne "${YELLOW}  Bio (one paragraph)${NC}: "
            read -r AGENT_BIO
            AGENT_BIO="${AGENT_BIO:-$AGENT_NAME is a dedicated real estate professional committed to helping clients find their perfect home.}"
            prompt AGENT_PHOTO "  Path to headshot photo"

            # Determine image filename
            agent_slug=$(slugify "$AGENT_NAME")
            if [ -n "$AGENT_PHOTO" ] && [ -f "$AGENT_PHOTO" ]; then
                ext="${AGENT_PHOTO##*.}"
                agent_img_file="agents/${agent_slug}.${ext}"
                AGENT_FILES+=("$AGENT_PHOTO|$agent_img_file")
            else
                agent_img_file="agents/${agent_slug}.jpg"
                AGENT_FILES+=("PLACEHOLDER|$agent_img_file")
            fi

            # Escape double quotes and backslashes in bio for JSON
            escaped_bio=$(echo "$AGENT_BIO" | sed 's/\\/\\\\/g; s/"/\\"/g')

            # Build JS object
            if [ -n "$AGENTS_JS" ]; then
                AGENTS_JS="${AGENTS_JS},"$'\n'
            fi
            AGENTS_JS="${AGENTS_JS}            {
                name: \"${AGENT_NAME}\",
                email: \"${AGENT_EMAIL}\",
                phone: \"${AGENT_PHONE}\",
                image: \"${agent_img_file}\",
                bio: \"${escaped_bio}\"
            }"

            echo -ne "${YELLOW}  Add another agent? (y/n)${NC} [n]: "
            read -r add_more
            add_more="${add_more:-n}"
        done
        ;;
    2)
        # CSV import
        prompt_required CSV_PATH "  Path to CSV file"
        if [ ! -f "$CSV_PATH" ]; then
            echo -e "${RED}  File not found: $CSV_PATH${NC}"
            echo -e "${YELLOW}  Continuing with empty agent list.${NC}"
        else
            echo -e "${GREEN}  Reading CSV...${NC}"
            first_line=true
            while IFS=',' read -r name email phone bio photo; do
                # Skip header row
                if [ "$first_line" = true ]; then
                    first_line=false
                    continue
                fi

                # Strip surrounding quotes
                name=$(echo "$name" | sed 's/^"//;s/"$//')
                email=$(echo "$email" | sed 's/^"//;s/"$//')
                phone=$(echo "$phone" | sed 's/^"//;s/"$//')
                bio=$(echo "$bio" | sed 's/^"//;s/"$//')
                photo=$(echo "$photo" | sed 's/^"//;s/"$//')

                agent_slug=$(slugify "$name")

                if [ -n "$photo" ] && [ -f "$photo" ]; then
                    ext="${photo##*.}"
                    agent_img_file="agents/${agent_slug}.${ext}"
                    AGENT_FILES+=("$photo|$agent_img_file")
                else
                    agent_img_file="agents/${agent_slug}.jpg"
                    AGENT_FILES+=("PLACEHOLDER|$agent_img_file")
                fi

                escaped_bio=$(echo "$bio" | sed 's/\\/\\\\/g; s/"/\\"/g')

                if [ -n "$AGENTS_JS" ]; then
                    AGENTS_JS="${AGENTS_JS},"$'\n'
                fi
                AGENTS_JS="${AGENTS_JS}            {
                name: \"${name}\",
                email: \"${email}\",
                phone: \"${phone}\",
                image: \"${agent_img_file}\",
                bio: \"${escaped_bio}\"
            }"

                echo -e "  Added: ${name}"
            done < "$CSV_PATH"
        fi
        ;;
    3|"")
        echo -e "${YELLOW}  Skipping agents. You can add them later in index.html.${NC}"
        ;;
esac

# Build the full agentsData block
if [ -n "$AGENTS_JS" ]; then
    AGENTS_DATA_BLOCK="const agentsData = [
${AGENTS_JS}
        ];"
else
    AGENTS_DATA_BLOCK='// To add agents, replace this with an array of agent objects:
        // const agentsData = [
        //     {
        //         name: "Agent Name",
        //         email: "agent@example.com",
        //         phone: "423-555-0100",
        //         image: "agents/agentname.jpg",
        //         bio: "Agent bio goes here."
        //     }
        // ];
        const agentsData = [];'
fi

echo ""

# ─────────────────────────────────────────
# Determine image filenames
# ─────────────────────────────────────────

if [ -n "$LOGO_PATH" ] && [ -f "$LOGO_PATH" ]; then
    LOGO_EXT="${LOGO_PATH##*.}"
    LOGO_FILE="logo.${LOGO_EXT}"
else
    LOGO_FILE="logo.png"
    LOGO_PATH=""
fi

if [ -n "$OG_IMAGE_PATH" ] && [ -f "$OG_IMAGE_PATH" ]; then
    OG_EXT="${OG_IMAGE_PATH##*.}"
    OG_IMAGE_FILE="og-image.${OG_EXT}"
else
    OG_IMAGE_FILE="og-image.png"
    OG_IMAGE_PATH=""
fi

if [ -n "$COMPANY_PHOTO_PATH" ] && [ -f "$COMPANY_PHOTO_PATH" ]; then
    PHOTO_EXT="${COMPANY_PHOTO_PATH##*.}"
    COMPANY_PHOTO_FILE="company-photo.${PHOTO_EXT}"
else
    COMPANY_PHOTO_FILE="company-photo.jpg"
    COMPANY_PHOTO_PATH=""
fi

# ─────────────────────────────────────────
# Review & confirm
# ─────────────────────────────────────────

echo -e "${BOLD}${GREEN}=========================================${NC}"
echo -e "${BOLD}${GREEN}  Review Your Settings${NC}"
echo -e "${BOLD}${GREEN}=========================================${NC}"
echo ""
echo -e "  ${BOLD}Company:${NC}      $COMPANY_NAME"
echo -e "  ${BOLD}Short Name:${NC}   $COMPANY_SHORT_NAME"
echo -e "  ${BOLD}Location:${NC}     $COMPANY_CITY, $COMPANY_STATE"
echo -e "  ${BOLD}Phone:${NC}        $COMPANY_PHONE"
echo -e "  ${BOLD}Email:${NC}        $COMPANY_EMAIL"
echo -e "  ${BOLD}Address:${NC}      $COMPANY_ADDRESS"
echo -e "  ${BOLD}FlexMLS ID:${NC}   $FLEXMLS_ID"
echo -e "  ${BOLD}Accent Color:${NC} $ACCENT_COLOR"
echo -e "  ${BOLD}Domain:${NC}       $COMPANY_DOMAIN"
echo -e "  ${BOLD}Logo:${NC}         ${LOGO_PATH:-defaults}"
echo -e "  ${BOLD}OG Image:${NC}     ${OG_IMAGE_PATH:-defaults}"
echo -e "  ${BOLD}Photo:${NC}        ${COMPANY_PHOTO_PATH:-defaults}"
echo -e "  ${BOLD}Agents:${NC}       ${#AGENT_FILES[@]} agent(s)"
echo -e "  ${BOLD}Output:${NC}       $OUTPUT_DIR"
echo ""
echo -ne "${YELLOW}Generate site with these settings? (y/n)${NC} [y]: "
read -r confirm
confirm="${confirm:-y}"

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo -e "${RED}Aborted.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Generating site...${NC}"

# ─────────────────────────────────────────
# Generate!
# ─────────────────────────────────────────

# Create output directories
mkdir -p "$OUTPUT_DIR/agents"

# --- index.html ---
# Write agents block to a temp file so Python can read it cleanly
AGENTS_TMPFILE=$(mktemp)
echo "$AGENTS_DATA_BLOCK" > "$AGENTS_TMPFILE"

# Export all variables so Python can read them via os.environ
export TEMPLATE_DIR OUTPUT_DIR AGENTS_TMPFILE
export COMPANY_NAME COMPANY_SHORT_NAME COMPANY_CITY COMPANY_STATE
export COMPANY_PHONE COMPANY_PHONE_RAW COMPANY_EMAIL COMPANY_ADDRESS
export COMPANY_ADDRESS_QUERY COMPANY_MISSION COMPANY_DOMAIN
export FLEXMLS_ID ACCENT_COLOR LOGO_FILE OG_IMAGE_FILE COMPANY_PHOTO_FILE

# Use Python for all replacements — handles special chars and multi-line content reliably
python3 << 'PYEOF'
import sys, os

template_path = os.path.join(os.environ.get("TEMPLATE_DIR", "template"), "index.html")
output_path = os.path.join(os.environ.get("OUTPUT_DIR", "output"), "index.html")
agents_path = os.environ.get("AGENTS_TMPFILE", "")

with open(template_path, "r") as f:
    content = f.read()

# Read agents block from temp file
agents_block = ""
if agents_path and os.path.exists(agents_path):
    with open(agents_path, "r") as f:
        agents_block = f.read().strip()

# Single-line replacements
replacements = {
    "{{COMPANY_NAME}}": os.environ.get("COMPANY_NAME", ""),
    "{{COMPANY_CITY}}": os.environ.get("COMPANY_CITY", ""),
    "{{COMPANY_STATE}}": os.environ.get("COMPANY_STATE", ""),
    "{{COMPANY_PHONE}}": os.environ.get("COMPANY_PHONE", ""),
    "{{COMPANY_PHONE_RAW}}": os.environ.get("COMPANY_PHONE_RAW", ""),
    "{{COMPANY_EMAIL}}": os.environ.get("COMPANY_EMAIL", ""),
    "{{COMPANY_DOMAIN}}": os.environ.get("COMPANY_DOMAIN", ""),
    "{{FLEXMLS_ID}}": os.environ.get("FLEXMLS_ID", ""),
    "{{ACCENT_COLOR}}": os.environ.get("ACCENT_COLOR", ""),
    "{{LOGO_FILE}}": os.environ.get("LOGO_FILE", ""),
    "{{OG_IMAGE_FILE}}": os.environ.get("OG_IMAGE_FILE", ""),
    "{{COMPANY_PHOTO_FILE}}": os.environ.get("COMPANY_PHOTO_FILE", ""),
    "{{COMPANY_ADDRESS}}": os.environ.get("COMPANY_ADDRESS", ""),
    "{{COMPANY_ADDRESS_QUERY}}": os.environ.get("COMPANY_ADDRESS_QUERY", ""),
    "{{COMPANY_MISSION}}": os.environ.get("COMPANY_MISSION", ""),
}

for token, value in replacements.items():
    content = content.replace(token, value)

# Multi-line replacement for agents
# Find the line containing {{AGENTS_DATA_ARRAY}} and replace the whole line
lines = content.split("\n")
new_lines = []
for line in lines:
    if "{{AGENTS_DATA_ARRAY}}" in line:
        # Preserve indentation
        indent = line[:len(line) - len(line.lstrip())]
        # Add indent to each line of agents block
        for i, agent_line in enumerate(agents_block.split("\n")):
            if i == 0:
                new_lines.append(indent + agent_line)
            else:
                new_lines.append(agent_line)
    else:
        new_lines.append(line)

content = "\n".join(new_lines)

with open(output_path, "w") as f:
    f.write(content)
PYEOF

# Clean up temp file
rm -f "$AGENTS_TMPFILE"

# --- manifest.json ---
sed \
    -e "s|{{COMPANY_NAME}}|${COMPANY_NAME}|g" \
    -e "s|{{COMPANY_SHORT_NAME}}|${COMPANY_SHORT_NAME}|g" \
    "$TEMPLATE_DIR/manifest.json" > "$OUTPUT_DIR/manifest.json"

# --- Generate or copy favicon ---
if [ -n "$LOGO_PATH" ] && [ -f "$LOGO_PATH" ] && command -v sips &>/dev/null; then
    cp "$LOGO_PATH" "$OUTPUT_DIR/favicon.png"
    sips -z 48 48 -s format png "$OUTPUT_DIR/favicon.png" --out "$OUTPUT_DIR/favicon.png" &>/dev/null
    echo -e "  ${GREEN}Generated favicon from logo (sips)${NC}"
elif [ -n "$LOGO_PATH" ] && [ -f "$LOGO_PATH" ] && command -v convert &>/dev/null; then
    convert "$LOGO_PATH" -resize 48x48! -format png "$OUTPUT_DIR/favicon.png"
    echo -e "  ${GREEN}Generated favicon from logo (ImageMagick)${NC}"
else
    cp "$DEFAULTS_DIR/favicon.png" "$OUTPUT_DIR/favicon.png"
    echo -e "  ${YELLOW}Using default favicon${NC}"
fi
cp "$DEFAULTS_DIR/icon-192x192.png" "$OUTPUT_DIR/icon-192x192.png"
cp "$DEFAULTS_DIR/icon-512x512.png" "$OUTPUT_DIR/icon-512x512.png"

# --- Copy/create logo ---
if [ -n "$LOGO_PATH" ] && [ -f "$LOGO_PATH" ]; then
    cp "$LOGO_PATH" "$OUTPUT_DIR/$LOGO_FILE"
else
    # Create a simple text-based logo placeholder
    echo -e "${YELLOW}  No logo provided. Creating placeholder. Replace $LOGO_FILE with your actual logo.${NC}"
    cp "$DEFAULTS_DIR/favicon.png" "$OUTPUT_DIR/$LOGO_FILE"
fi

# --- Copy/create OG image ---
if [ -n "$OG_IMAGE_PATH" ] && [ -f "$OG_IMAGE_PATH" ]; then
    cp "$OG_IMAGE_PATH" "$OUTPUT_DIR/$OG_IMAGE_FILE"
else
    echo -e "${YELLOW}  No OG image provided. Creating placeholder. Replace $OG_IMAGE_FILE with your actual image.${NC}"
    cp "$DEFAULTS_DIR/favicon.png" "$OUTPUT_DIR/$OG_IMAGE_FILE"
fi

# --- Copy/create company photo ---
if [ -n "$COMPANY_PHOTO_PATH" ] && [ -f "$COMPANY_PHOTO_PATH" ]; then
    cp "$COMPANY_PHOTO_PATH" "$OUTPUT_DIR/$COMPANY_PHOTO_FILE"
else
    echo -e "${YELLOW}  No company photo provided. Creating placeholder. Replace $COMPANY_PHOTO_FILE with your actual photo.${NC}"
    cp "$DEFAULTS_DIR/placeholder-agent.jpg" "$OUTPUT_DIR/$COMPANY_PHOTO_FILE"
fi

# --- Copy agent photos ---
for agent_file_entry in "${AGENT_FILES[@]}"; do
    src="${agent_file_entry%%|*}"
    dest="${agent_file_entry##*|}"
    if [ "$src" = "PLACEHOLDER" ]; then
        cp "$DEFAULTS_DIR/placeholder-agent.jpg" "$OUTPUT_DIR/$dest"
    elif [ -f "$src" ]; then
        cp "$src" "$OUTPUT_DIR/$dest"
    else
        echo -e "${YELLOW}  Agent photo not found: $src — using placeholder${NC}"
        cp "$DEFAULTS_DIR/placeholder-agent.jpg" "$OUTPUT_DIR/$dest"
    fi
done

# ─────────────────────────────────────────
# Done!
# ─────────────────────────────────────────

echo ""
echo -e "${BOLD}${GREEN}=========================================${NC}"
echo -e "${BOLD}${GREEN}  Site Generated Successfully!${NC}"
echo -e "${BOLD}${GREEN}=========================================${NC}"
echo ""
echo -e "  ${BOLD}Output:${NC} $OUTPUT_DIR/"
echo ""

# List generated files
echo -e "  ${BOLD}Files:${NC}"
ls -1 "$OUTPUT_DIR" | while read -r f; do
    if [ -d "$OUTPUT_DIR/$f" ]; then
        echo -e "    ${CYAN}$f/${NC}"
        ls -1 "$OUTPUT_DIR/$f" | while read -r sf; do
            echo -e "      $sf"
        done
    else
        echo -e "    $f"
    fi
done

echo ""
echo -e "${BOLD}${GREEN}--- Next Steps ---${NC}"
echo ""
echo -e "  ${BOLD}1. Test locally:${NC}"
echo -e "     cd $OUTPUT_DIR && python3 -m http.server 8080"
echo -e "     Then visit http://localhost:8080"
echo ""
echo -e "  ${BOLD}2. Replace placeholder images:${NC}"
if [ -z "$LOGO_PATH" ]; then
echo -e "     - ${LOGO_FILE} (your company banner logo)"
fi
if [ -z "$OG_IMAGE_PATH" ]; then
echo -e "     - ${OG_IMAGE_FILE} (social media preview image)"
fi
if [ -z "$COMPANY_PHOTO_PATH" ]; then
echo -e "     - ${COMPANY_PHOTO_FILE} (photo for About modal)"
fi
echo ""
echo -e "  ${BOLD}3. Deploy to any static host:${NC}"
echo -e "     - Upload files to your web server"
echo -e "     - Or use Caddy, Nginx, Apache, Netlify, etc."
echo ""
echo -e "  ${BOLD}Example Caddy config:${NC}"
echo -e "     yourdomain.com {"
echo -e "         root * /var/www/your-site"
echo -e "         file_server"
echo -e "         encode gzip"
echo -e "         try_files {path} {path}/ /index.html"
echo -e "     }"
echo ""
echo -e "  ${BOLD}4. Property listing redirects:${NC}"
echo -e "     Copy template/property-redirect.html for individual listings."
echo -e "     Replace {{FLEXMLS_LISTING_URL}} and {{LOGO_FILE}} with real values."
echo ""
