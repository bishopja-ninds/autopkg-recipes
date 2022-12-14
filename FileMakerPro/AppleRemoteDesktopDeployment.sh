#!/bin/sh

#############################################################################
#############################################################################
###
### Copyright Claris International Inc. 2020
###
###	Purpose:	Create a PackageMaker installer package suitable for mass
###				deploying FileMaker Pro via Apple Remote Desktop.
###
### Usage:	
###				sudo chmod +x ./AppleRemoteDesktopDeployment.sh
###				./AppleRemoteDesktopDeployment.sh "<folder 1>"
###
###				Make it an executable script by changing the permissions
###				of the script via chmod.
###
###				Where "<folder 1>" contains the FileMaker Pro application
###				along with the Assisted Install.txt file and LicenseCert.fmcert
###
### Required:
###				1.  The command line tool pkgbuild is required.  pkgbuild
###					is available by default on OS X Systems 10.7 and greater.
###					For Systems 10.6.x, pkgbuild can be installed on the
###					System by installing XCode available from Apple, Inc.
###				2.  A folder, ie. "<folder 1>" containing a FileMaker Pro
###					application; and containing an Assisted Install.txt file and
###					LicenseCert.fmcert
###				3.  The Assisted Install.txt file should contain a username
###					and license key.  The other Assisted Install.txt options,
###					such as AI_DISABLEPLUGINS, etc., should be set as needed.
###
###	Output:		The output of this script is an installer package named
###				"* ARD.pkg", placed in "<folder 1>", that is suitable for
###				mass deploying FileMaker Pro via Apple Remote Desktop.
###
#############################################################################
#############################################################################

root=$1

if [ -d "$root" ] ; then
	AppleRemoteDesktopRoot=$root/AppleRemoteDesktopPackage
	scriptsFolder=$root/Scripts
	postinstall=$scriptsFolder/postinstall
	identifier=com.filemaker.ardwrapper.FileMakerProARD.pkg
	installLocation=/Applications
	plistFile=FMP.plist

    ### Get the app bundle name - begin
    pushd "${root}" > /dev/null
    appBundleName=`ls -d *.app`
    licenseCert=`ls -d *.fmcert`
    popd > /dev/null
    ### Get the app bundle name - end

    appBundleVersion=`/usr/libexec/plistbuddy -c "Print CFBundleVersion" "${root}/${appBundleName}/Contents/Info.plist"`

    echo appBundleName=${appBundleName}
    echo appBundleVersion=${appBundleVersion}

    MAJOR_VERSION=`echo "$appBundleVersion" | awk '{split ($0, a, "."); print a[1]}'`
    fileExtension=${appBundleName##*.}
    appNameWithoutTheFileExtension=`basename -s .${fileExtension} "${appBundleName}"`
    FULL_PRIVILEGES=777
    APP_PRIVILEGES=775
    bundleIdentifier=com.filemaker.client.pro12

	CreatePostInstallScript(){
		echo "#!/bin/sh" > "${postinstall}"
		echo "chown -R root:admin \"/Applications/${appBundleName}\"" >> "${postinstall}"
		echo "chmod -R ${APP_PRIVILEGES} \"/Applications/${appBundleName}\"" >> "${postinstall}"
		echo "chmod ${FULL_PRIVILEGES} \"/Applications/${appBundleName}/Contents/MacOS\"" >> "${postinstall}"
		echo "chmod ${FULL_PRIVILEGES} \"/Applications/${appBundleName}/Contents\"" >> "${postinstall}"
        # Create the /Users/Shared folder for this product and version if it does not exist:
        echo "if [ ! -e \"/Users/Shared/FileMaker/FileMaker Pro/${MAJOR_VERSION}.0\" ] ; then" >> "${postinstall}"
            echo "mkdir -p \"/Users/Shared/FileMaker/FileMaker Pro/${MAJOR_VERSION}.0\"" >> "${postinstall}"
		    echo "chmod -R ${FULL_PRIVILEGES} \"/Users/Shared/FileMaker/FileMaker Pro/${MAJOR_VERSION}.0\"" >> "${postinstall}"
        echo "fi" >> "${postinstall}"
        #  Handle the Assisted Install.txt file if any:
        if [ -e "${root}/Assisted Install.txt" ] ; then
		    echo "cd \"/Applications/${appBundleName}/Contents/Resources/Installer\"" >> "${postinstall}"
            echo "./ApplicationPostFlight \"/Applications/Assisted Install.txt\" \"/Users/Shared/FileMaker/FileMaker Pro/${MAJOR_VERSION}.0\"" >> "${postinstall}"
            LICENSE_ACCEPTED=`grep AI_LICENSE_ACCEPTED "$root/Assisted Install.txt" | sed -e s/AI_LICENSE_ACCEPTED=//g`
            if [ ! "$LICENSE_ACCEPTED" = "" ]; then
                echo "defaults write ~/Library/Preferences/${bundleIdentifier}.plist \"License Agreement Status:_v${MAJOR_VERSION}.0\" -int ${LICENSE_ACCEPTED}" >> "${postinstall}"
                echo "chmod ${FULL_PRIVILEGES} ~/Library/Preferences/${bundleIdentifier}.plist" >> "${postinstall}"
            fi
            LAUNCH_CUSTOMAPP=`grep AI_LAUNCH_CUSTOMAPP "$root/Assisted Install.txt" | sed -e s/AI_LAUNCH_CUSTOMAPP=//g`
            if [ ! "$LAUNCH_CUSTOMAPP" = "" ]; then
                echo "defaults write ~/Library/Preferences/${bundleIdentifier}.plist \"Preferences:Initialfile\" \"${LAUNCH_CUSTOMAPP}\"" >> "${postinstall}"
                echo "defaults write ~/Library/Preferences/${bundleIdentifier}.plist \"Preferences:UseInitialfile\" -int 1" >> "${postinstall}"
                echo "chmod ${FULL_PRIVILEGES} ~/Library/Preferences/${bundleIdentifier}.plist" >> "${postinstall}"
            fi
            echo "rm -f \"/Applications/Assisted Install.txt\"" >> "${postinstall}"
            echo "chmod ${FULL_PRIVILEGES} \"/Users/Shared/FileMaker/FileMaker Pro/${MAJOR_VERSION}.0/pInfo\"" >> "${postinstall}"
        fi
        #  Handle the license cert if any:
        if [ "$licenseCert" != "" ] ; then
		    echo "ditto /Applications/${licenseCert} \"/Users/Shared/FileMaker/FileMaker Pro/${MAJOR_VERSION}.0\"" >> "${postinstall}"
            echo "rm -f \"/Applications/${licenseCert}\"" >> "${postinstall}"
            echo "chmod ${FULL_PRIVILEGES} \"/Users/Shared/FileMaker/FileMaker Pro/${MAJOR_VERSION}.0/${licenseCert}\"" >> "${postinstall}"
        fi
        echo "rm -f \"/Applications/${plistFile}\"" >> "${postinstall}"
	}
	
	mkdir -p "${AppleRemoteDesktopRoot}" "${scriptsFolder}"
	CreatePostInstallScript
	chmod +x "${postinstall}"
    ditto "${root}/${appBundleName}" "${AppleRemoteDesktopRoot}/${appBundleName}"
    ditto "${root}/Assisted Install.txt" "${AppleRemoteDesktopRoot}/Assisted Install.txt"
    ditto "${root}/${licenseCert}" "${AppleRemoteDesktopRoot}/${licenseCert}"
	pkgbuild --analyze --root "${AppleRemoteDesktopRoot}" "${AppleRemoteDesktopRoot}/${plistFile}"
	plutil -replace BundleIsRelocatable -bool NO "${AppleRemoteDesktopRoot}/${plistFile}"
    pkgbuild --identifier $identifier --scripts "${scriptsFolder}" --install-location $installLocation --root "${AppleRemoteDesktopRoot}" --component-plist "${AppleRemoteDesktopRoot}/${plistFile}" "${root}/FileMakerPro-${appBundleVersion}.pkg"
    rm -dfR "${AppleRemoteDesktopRoot}"
    rm -dfR "${scriptsFolder}"
else
	echo 
	echo Usage:		./AppleRemoteDesktopDeployment.sh "<folder 1>"
	echo 
	echo 			Where "<folder 1>" contains the FileMaker Pro.app
	echo 			along with the Assisted Install.txt file and the LicenseCert.fmcert
	echo 			file.
	echo 
fi
