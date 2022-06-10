# Required installs:
# - plcncli
# - sdk
# - unzip
# - sshpass

setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    
    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    TMP_DIR="/tmp"
#    PROJECT_NAME="DynamicPorts"
    PROJECT_NAME="DynamicPorts"
    PROJECT_DIR="$DIR/../Examples/$PROJECT_NAME"
    TARGET="AXCF2152"
    VERSION="22.0.4.144"  # Note the version format
    IP_ADDR="192.168.1.10"
    USERNAME="admin"
    PASSWORD="88f037bb"
}

@test "DynamicPorts Example" {
    cd ${TMP_DIR}

    # Unzip the PLCnext Engineer project
#    unzip ${PROJECT_DIR}/${PROJECT_NAME}.pcwex -d eng

    # Create the project
    run plcncli new project --name ${PROJECT_NAME}
    assert_output --partial 'Successfully created template'

    # Enter the project directory
    cd ${TMP_DIR}/${PROJECT_NAME}

    # Replace the auto-generated project file(s) with the example
    cp ${PROJECT_DIR}/src/* ./src

    # Assign target
    run plcncli set target --add --name ${TARGET} --version ${VERSION}
    assert_output --partial 'Successfully added target'

    # Generate code
    run plcncli generate code
    assert_output --partial 'Successfully generated all files'

    # Generate config
    run plcncli generate config
    assert_output --partial 'Successfully generated all files'

    # Build project
    run plcncli build
    assert_output --partial 'Successfully built the project'

    # Deploy project
    run plcncli deploy
    assert_output --partial 'Successfully deployed all files'

    # Copy the library to the target
    sshpass -p ${PASSWORD} scp -r ${TMP_DIR}/${PROJECT_NAME}/bin/${TARGET}_${VERSION}/Release ${USERNAME}@${IP_ADDR}:/opt/plcnext/projects/${PROJECT_NAME}

    # Copy configuration files to the target
    sshpass -p ${PASSWORD} scp -r ${PROJECT_DIR}/dynaports.json ${USERNAME}@${IP_ADDR}:/opt/plcnext/
    sshpass -p ${PASSWORD} scp -r ${PROJECT_DIR}/Plc/* ${USERNAME}@${IP_ADDR}:/opt/plcnext/projects/Default/Plc/

    # Restart the PLCnext Runtime
    run sshpass -p ${PASSWORD} ssh ${USERNAME}@${IP_ADDR} "echo ${PASSWORD} | sudo -S /etc/init.d/plcnext restart"
    assert_output --partial 'plcnext started'

    # Check the Output.log file for the expected message
    run sshpass -p ${PASSWORD} ssh ${USERNAME}@${IP_ADDR} "timeout 60s tail -f -n 0 /opt/plcnext/logs/Output.log"
    assert_output --partial 'Number of dynamic ports used: 4'
}

teardown() {
    rm -rf ${TMP_DIR}/${PROJECT_NAME}
}
