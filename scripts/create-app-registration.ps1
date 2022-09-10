appInfo=$(az ad app create --display-name $1 --identifier-uris \"$2\" --reply-urls \"$3\")
echo $appInfo > $AZ_SCRIPTS_OUTPUT_PATH