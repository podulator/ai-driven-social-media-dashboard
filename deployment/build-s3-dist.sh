#!/bin/bash

# This assumes all of the OS-level configuration has been completed and git repo has already been cloned
#sudo yum-config-manager --enable epel
#sudo yum update -y
#sudo pip install --upgrade pip
#alias sudo='sudo env PATH=$PATH'
#sudo  pip install --upgrade setuptools
#sudo pip install --upgrade virtualenv

# This script should be run from the repo's deployment directory
# cd deployment
# ./build-s3-dist.sh source-bucket-base-name
# source-bucket-base-name should be the base name for the S3 bucket location where the template will source the Lambda code from.
# The template will append '-[region_name]' to this bucket name.
# For example: ./build-s3-dist.sh solutions
# The template will then expect the source code to be located in the solutions-[region_name] bucket

# Check to see if input has been provided:
if [ -z "$2" ]; then
    echo "Please provide the base source bucket name and version where the lambda code will eventually reside."
    echo "For example: ./build-s3-dist.sh solutions v1.0"
    exit 1
fi

# work out what platform we are on, and set sed up accordingly
if [[ "$OSTYPE" == "darwin"* ]]; then
  sedFlags="-i '' -e "
else
  sedFlags="-i -e "
fi

# Build source
echo "Staring to build distribution"
# Create variable for deployment directory to use as a reference for builds
echo "export deployment_dir=`pwd`"
export deployment_dir=`pwd`

# Make deployment/dist folder for containing the built solution
echo "mkdir -p ${deployment_dir}/dist"
if [ -d ${deployment_dir}/dist ]; then
    rm -rf ${deployment_dir}/dist
fi
mkdir -p ${deployment_dir}/dist
if [ ! -d ${deployment_dir}/dist ]; then
    echo "Couldn't create directiory : ${deployment_dir}"
    exit 1
fi

# Copy project CFN template(s) to "dist" folder and replace bucket name with arg $1
echo "cp -f ai-driven-social-media-dashboard.template ${deployment_dir}/dist/ai-driven-social-media-dashboard.template"
cp -f ai-driven-social-media-dashboard.template ${deployment_dir}/dist/ai-driven-social-media-dashboard.template
if [ ! -f ${deployment_dir}/dist/ai-driven-social-media-dashboard.template ]; then
    echo "Couldn't copy file to dist folder"
    exit 1
fi

echo "Updating code source bucket in template with ${1}"
replace="s/__BUCKET_NAME__/${1}/g"
templatePath="${deployment_dir}/dist/ai-driven-social-media-dashboard.template"
echo "sed ${sedFlags} '${replace}' \"${templatePath}\""
sed ${sedFlags} "${replace}" "${templatePath}"
success=$?
if [ $success -ne 0 ]; then
    echo "sed failed to update bucket name with exit code : $success"
    exit 1
fi

echo "Updating code source version in template with ${1}"
replace="s/__VERSION__/${2}/g"
echo "sed ${sedFlags} ${replace} \"${templatePath}\""
sed ${sedFlags} "${replace}" "${templatePath}"
if [ $? -ne 0 ]; then
    echo "sed failed to update version number with exit code : $?"
    exit 2
fi

# Package socialmediafunction Lambda function
echo "Packaging socialmediafunction lambda"
cd ${deployment_dir}/../source/socialmediafunction/
zip -q -r9 ${deployment_dir}/dist/socialmediafunction.zip *
if [ ! -f ${deployment_dir}/dist/socialmediafunction.zip ]; then
    echo "Couldn't build zip file : ${deployment_dir}/dist/socialmediafunction.zip"
    exit 3
fi

# Package addtriggerfunction Lambda function
echo "Packaging addtriggerfunction lambda"
cd ${deployment_dir}/../source/addtriggerfunction/
zip -q -r9 ${deployment_dir}/dist/addtriggerfunction.zip *
if [ ! -f ${deployment_dir}/dist/addtriggerfunction.zip ]; then
    echo "Couldn't build zip file : ${deployment_dir}/dist/addtriggerfunction.zip"
    exit 3
fi

#zipping code for ec2
echo "tarring ec2 twitter reader code"
cd ${deployment_dir}/../source/ec2_twitter_reader/

echo "npm ci"
npm ci 2>/dev/null 1>/dev/null
success=$?
if [ $success -ne 0 ]; then
    echo "npm install failed with exit code : $success"
    exit 4
fi

echo "npm run build"
npm run build 2>/dev/null 1>/dev/null
success=$?
if [ $success -ne 0 ]; then
    echo "npm run build failed with exit code : $success"
    exit 4
fi

echo "npm run tar"
npm run tar > /dev/null
success=$?
if [ $success -ne 0 ]; then
    echo "npm run tar failed with exit code : $success"
    exit 4
fi

# Copy packaged Lambda function to $deployment_dir/dist
cp ./dist/ec2_twitter_reader.tar ${deployment_dir}/dist/ec2_twitter_reader.tar

echo "cleaning up"
# Remove temporary build files
rm -rf dist
rm -rf node_modules

# Done, so go back to deployment_dir
cd ${deployment_dir}
