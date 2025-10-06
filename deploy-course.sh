#!/bin/bash

# AWS Well-Architected Framework 10-Day Crash Course Deployment Script
# Validates prerequisites and sets up course environment

set -e

# Configuration
REGION="us-east-1"
COURSE_NAME="well-architected-crash-course"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"; }

# Check prerequisites
check_prerequisites() {
    log "Checking course prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error "AWS CLI not installed. Please install AWS CLI v2"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured. Run 'aws configure'"
        exit 1
    fi
    
    # Check permissions
    log "Validating AWS permissions..."
    aws iam list-roles --max-items 1 &> /dev/null || {
        error "Insufficient IAM permissions. Need AdministratorAccess for course"
        exit 1
    }
    
    # Set region
    aws configure set region $REGION
    
    log "Prerequisites check completed successfully"
}

# Validate course structure
validate_structure() {
    log "Validating course structure..."
    
    for day in {01..10}; do
        day_dir="day-${day}-*"
        if ! ls -d $day_dir &> /dev/null; then
            warn "Day $day directory not found"
        fi
    done
    
    log "Course structure validation completed"
}

# Setup course environment
setup_environment() {
    log "Setting up course environment..."
    
    # Create course-specific S3 bucket for resources
    BUCKET_NAME="${COURSE_NAME}-resources-$(aws sts get-caller-identity --query Account --output text)"
    
    if ! aws s3 ls s3://$BUCKET_NAME &> /dev/null; then
        aws s3 mb s3://$BUCKET_NAME --region $REGION
        log "Created course resources bucket: $BUCKET_NAME"
    fi
    
    # Create course progress tracking
    cat > course-progress.json << EOF
{
    "course": "AWS Well-Architected Framework Crash Course",
    "student": "$(aws sts get-caller-identity --query Arn --output text)",
    "start_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "progress": {
        "day_01": {"status": "not_started", "projects_completed": 0},
        "day_02": {"status": "not_started", "projects_completed": 0},
        "day_03": {"status": "not_started", "projects_completed": 0},
        "day_04": {"status": "not_started", "projects_completed": 0},
        "day_05": {"status": "not_started", "projects_completed": 0},
        "day_06": {"status": "not_started", "projects_completed": 0},
        "day_07": {"status": "not_started", "projects_completed": 0},
        "day_08": {"status": "not_started", "projects_completed": 0},
        "day_09": {"status": "not_started", "projects_completed": 0},
        "day_10": {"status": "not_started", "projects_completed": 0}
    }
}
EOF
    
    aws s3 cp course-progress.json s3://$BUCKET_NAME/
    
    log "Course environment setup completed"
}

# Generate student guide
generate_student_guide() {
    log "Generating student guide..."
    
    cat > STUDENT-GUIDE.md << 'EOF'
# AWS Well-Architected Framework - Student Guide

## Welcome to the 10-Day Crash Course!

### Course Overview
- **Duration**: 10 days (50 hours total)
- **Format**: 1 hour theory + 4 hours hands-on labs daily
- **Projects**: 30 mini-projects across all five pillars
- **Outcome**: Production-ready AWS architecture skills

### Daily Schedule
- **09:00-10:00**: Theory and concepts
- **10:00-11:30**: Project 1 (Basic)
- **11:30-13:00**: Project 2 (Intermediate)  
- **14:00-15:30**: Project 3 (Advanced)
- **15:30-16:00**: Review and Q&A

### Prerequisites Checklist
- [ ] AWS account with AdministratorAccess
- [ ] AWS CLI v2 installed and configured
- [ ] Basic understanding of cloud concepts
- [ ] Text editor or IDE ready
- [ ] Notebook for taking notes

### Course Materials
Each day folder contains:
- README.md with project overview
- Theory presentation materials
- Step-by-step lab guides
- CloudFormation templates
- Sample code and scripts

### Success Tips
1. **Follow the sequence**: Each day builds on previous days
2. **Take notes**: Document your learnings and challenges
3. **Ask questions**: Use discussion forums or instructor time
4. **Practice**: Repeat labs if needed for understanding
5. **Apply**: Think about how to use patterns in real projects

### Assessment
- Daily knowledge checks (80% pass required)
- Project completion verification
- Final Well-Architected review
- Peer presentation (10 minutes)

### Support Resources
- Course Slack channel: #well-architected-course
- Office hours: Daily 16:00-17:00
- AWS Documentation: https://docs.aws.amazon.com
- Well-Architected Framework: https://aws.amazon.com/architecture/well-architected/

### Getting Started
1. Run `./deploy-course.sh` to validate setup
2. Start with Day 1 theory presentation
3. Complete projects in order
4. Track progress in course-progress.json

Good luck with your Well-Architected journey!
EOF
    
    log "Student guide generated: STUDENT-GUIDE.md"
}

# Main setup function
main() {
    log "Starting AWS Well-Architected Framework Course Setup"
    log "Course: $COURSE_NAME"
    log "Region: $REGION"
    
    check_prerequisites
    validate_structure
    setup_environment
    generate_student_guide
    
    log "🎉 Course setup completed successfully!"
    log "📚 Read STUDENT-GUIDE.md to get started"
    log "🚀 Begin with Day 1: Well-Architected Framework Introduction"
    
    echo ""
    echo "Next steps:"
    echo "1. Read STUDENT-GUIDE.md"
    echo "2. cd day-01-introduction"
    echo "3. Follow the README.md instructions"
    echo "4. Complete all three projects"
    echo "5. Move to day-02-operational-excellence-1"
}

# Cleanup function
cleanup() {
    log "Cleaning up course resources..."
    
    BUCKET_NAME="${COURSE_NAME}-resources-$(aws sts get-caller-identity --query Account --output text)"
    
    # Empty and delete S3 bucket
    aws s3 rm s3://$BUCKET_NAME --recursive || true
    aws s3 rb s3://$BUCKET_NAME || true
    
    # Remove local files
    rm -f course-progress.json
    
    log "Cleanup completed"
}

# Script execution
case "${1:-setup}" in
    setup)
        main
        ;;
    cleanup)
        cleanup
        ;;
    validate)
        check_prerequisites
        validate_structure
        ;;
    *)
        echo "Usage: $0 [setup|cleanup|validate]"
        echo "  setup    - Set up course environment (default)"
        echo "  cleanup  - Remove course resources"
        echo "  validate - Check prerequisites only"
        exit 1
        ;;
esac
