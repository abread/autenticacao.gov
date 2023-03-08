/*-****************************************************************************

 * Copyright (C) 2017-2022 Adriano Campos - <adrianoribeirocampos@gmail.com>
 * Copyright (C) 2017-2018 André Guerreiro - <aguerreiro1985@gmail.com>
 * Copyright (C) 2018-2019 Miguel Figueira - <miguel.figueira@caixamagica.pt>
 * Copyright (C) 2018-2019 Veniamin Craciun - <veniamin.craciun@caixamagica.pt>
 * Copyright (C) 2019 José Pinto - <jose.pinto@caixamagica.pt>
 *
 * Licensed under the EUPL V.1.2

****************************************************************************-*/

import QtQuick 2.6
import QtQuick.Controls 2.1

/* Constants imports */
import "../../scripts/Constants.js" as Constants
import "../../scripts/Functions.js" as Functions
import "../../components" as Components

//Import C++ defined enums
import eidguiV2 1.0

PageServicesSignForm {

    property bool isAnimationFinished: mainFormID.propertyPageLoader.propertyAnimationExtendedFinished
    property string propertyOutputSignedFile : ""
    property string ownerNameBackup: ""
    property string ownerAttrBackup: ""
    property string ownerEntitiesBackup: ""

    ToolTip {
        property var maxWidth: 500
        id: controlToolTip
        contentItem:
            Text {
                id: tooltipText
                text: controlToolTip.text
                font: controlToolTip.font
                color: Constants.COLOR_MAIN_BLACK
                wrapMode: Text.WordWrap
                onTextChanged: {
                    controlToolTip.width = Math.min(controlToolTip.maxWidth, controlToolTip.implicitWidth)
                }
            }

        background: Rectangle {
            border.color: Constants.COLOR_MAIN_DARK_GRAY
            color: Constants.COLOR_MAIN_SOFT_GRAY
        }

        Timer {
            id: tooltipExitTimer
            interval: Constants.TOOLTIP_TIMEOUT_MS
            onTriggered: {
                controlToolTip.close()
                stop()
            }
        }
    }
    Keys.onRightPressed: {
        if(propertyTextAttributesMsg.activeFocus)
            jumpToDefinitionsSCAP()
    }
    Keys.onSpacePressed: {
        if(propertyTextAttributesMsg.activeFocus)
            jumpToDefinitionsSCAP()
    }
    Keys.onReturnPressed: {
        if(propertyTextAttributesMsg.activeFocus)
            jumpToDefinitionsSCAP()
    }

    Keys.onPressed: {
        console.log("PageServicesSignForm onPressed:" + event.key)
        Functions.detectBackKeys(event.key, Constants.MenuState.SUB_MENU)

        // CTRL + V
        if ((event.key == Qt.Key_V) && (event.modifiers & Qt.ControlModifier)){
            filesArray = controler.getFilesFromClipboard();
            propertyDropArea.dropped(filesArray);
        }

    }
    Connections {
        target: gapi
        onSignalGenericError: {
            propertyBusyIndicator.running = false
            mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
        }
        onSignalAttributesLoaded:{
            console.log("Sign advanced - Signal SCAP attributes loaded")
            append_attributes_to_model(institution_attributes)
            append_attributes_to_model(enterprise_attributes)

            for (var i = 0; i < propertyPageLoader.attributeListBackup.length; i++){
                entityAttributesModel.get(i).checkBoxAttr = propertyPageLoader.attributeListBackup[i]
            }

            propertyBusyIndicator.running = false
            propertyListViewEntities.currentIndex = 0
            entityAttributesModel.count > 0
                    ? propertyListViewEntities.forceActiveFocus()
                    : propertyTextAttributesMsg.forceActiveFocus()

            propertyItemOptions.height = propertyOptionsHeight

            // Scroll down to see attributes rectangle
            if (!propertyFlickable.atYEnd) {
                var velocity = Math.min(getMaxFlickVelocity(), Constants.FLICK_Y_VELOCITY_MAX_ATTR_LIST)
                propertyFlickable.flick(0, - velocity)
            }
        }
        onSignalPdfSignSuccess: {
            signsuccess_dialog.open()
            propertyBusyIndicator.running = false
            mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
            // test time stamp
            if(error_code == GAPI.SignMessageTimestampFailed){
                if(propertyListViewFiles.count > 1 && propertyRadioButtonPADES.checked){
                    signsuccess_dialog.propertySignSuccessDialogText.text =
                            qsTranslate("PageServicesSign","STR_TIME_STAMP_MULTI_FAILED")
                }else{
                    signsuccess_dialog.propertySignSuccessDialogText.text =
                            qsTranslate("PageServicesSign","STR_TIME_STAMP_FAILED")
                }
            }else if(error_code == GAPI.SignMessageLtvFailed){
                signsuccess_dialog.propertySignSuccessDialogText.text = qsTranslate("GAPI","STR_LTV_FAILED")
            }else{ // Sign with time stamp succefull
                signsuccess_dialog.propertySignSuccessDialogText.text = ""
            }
        }

        onSignalSignatureFinished: {
            propertyBusyIndicator.running = false
            mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
        }

        onSignalPdfSignFail: {
            console.log("Sign failed with error code: " + error_code)

            var error_text = ""
            if ( index != -1 ){ //batch signature failed
                var filename = Functions.fileBaseName(propertyListViewFiles.model.get(index).fileUrl)
                error_text = qsTranslate("PageServicesSign","STR_SIGN_BATCH_FAILED") + filename
            }

            var generic_text = ""
            if (error_code == GAPI.SignFilePermissionFailed) {
                generic_text = qsTranslate("PageServicesSign","STR_SIGN_FILE_PERMISSION_FAIL")
            } else if (error_code == GAPI.PDFFileUnsupported) {
                generic_text = qsTranslate("PageServicesSign","STR_SIGN_PDF_FILE_UNSUPPORTED")
            } else {
                generic_text = qsTranslate("PageServicesSign","STR_SIGN_GENERIC_ERROR") + " " + error_code
            }

            show_error_message(error_text, generic_text)
        }

        onSignalPdfBatchSignFail: {
            var batch_error_text = qsTranslate("PageServicesSign","STR_SIGN_BATCH_FAILED") + filename
            var generic_text
            if (error_code == GAPI.SignFilePermissionFailed) {
                generic_text = qsTranslate("PageServicesSign","STR_SIGN_FILE_PERMISSION_FAIL")
            } else if (error_code == GAPI.PDFFileUnsupported) {
                generic_text = qsTranslate("PageServicesSign","STR_SIGN_PDF_FILE_UNSUPPORTED")
            } else {
                generic_text = qsTranslate("PageServicesSign","STR_SIGN_GENERIC_ERROR") + " " + error_code
            }
            show_error_message(batch_error_text, generic_text)
        }

        onSignalSCAPServiceFail: {
            console.log("Sign advanced - Signal SCAP Service Fail")
            signerror_dialog.propertySignFailDialogGenericText.text = ""

            if(pdfsignresult == GAPI.ScapAttributesExpiredError ||
                    pdfsignresult == GAPI.ScapZeroAttributesError ||
                    pdfsignresult == GAPI.ScapNotValidAttributesError){
                console.log("ScapAttributesExpiredError")
                signerror_dialog.propertySignFailDialogText.text =
                        qsTranslate("PageServicesSign","STR_SCAP_NOT_VALID_ATTRIBUTES")

                // Show button to load attributes
                closeButtonError.visible = false
                buttonLoadAttr.visible = true
                buttonCancelAttr.visible = true
            }
            else if (pdfsignresult === GAPI.ScapAttrPossiblyExpiredWarning) {
                console.log("ScapAttrPossiblyExpiredWarning")
                signerror_dialog.propertySignFailDialogText.text =
                        qsTranslate("PageServicesSign","STR_SIGN_SCAP_SERVICE_FAIL") + "<br><br>"
                        + qsTranslate("GAPI","STR_SCAP_CHECK_EXPIRED_ATTR")

                closeButtonError.visible = false
                buttonLoadAttr.visible = true
                buttonCancelAttr.visible = true
            }
            else if(pdfsignresult === GAPI.ScapClockError){
                console.log("ScapClockError")
                signerror_dialog.propertySignFailDialogText.text =
                        qsTranslate("GAPI","STR_SCAP_CLOCK_ERROR")
            }
            else if(pdfsignresult === GAPI.ScapSecretKeyError){
                console.log("ScapSecretKeyError")
                signerror_dialog.propertySignFailDialogText.text =
                        qsTranslate("GAPI","STR_SCAP_SECRETKEY_ERROR")
                closeButtonError.visible = false
                buttonLoadAttr.visible = true
                buttonCancelAttr.visible = true
            }
            else {
                console.log("ScapGenericError")
                signerror_dialog.propertySignFailDialogText.text =
                    qsTranslate("PageServicesSign","STR_SIGN_SCAP_SERVICE_FAIL")
            }
            signerror_dialog.visible = true
            propertyBusyIndicator.running = false
            mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
            propertyOutputSignedFile = ""
        }

        onSignalSCAPConnectionFailed: {
            console.log("Scap connection failed")

            var text_top = qsTranslate("PageServicesSign", "STR_SCAP_PING_FAIL_FIRST")
            var text_bottom = qsTranslate("PageServicesSign", "STR_SCAP_PING_FAIL_SECOND")

            show_error_message(text_top, text_bottom)
        }

        onSignalSCAPBadCredentials: {
            console.log("Scap Bad Credentials")

            var text_top = qsTranslate("PageServicesSign", "STR_SCAP_BAD_CREDENTIALS")

            show_error_message(text_top, "")
        }

        onSignalSCAPPossibleProxyMisconfigured: {
            console.log("Scap possible misconfiguration of proxy")

            var text_top = qsTranslate("PageServicesSign","STR_SCAP_PING_FAIL_FIRST")
            var text_bottom = qsTranslate("PageServicesSign", "STR_SCAP_PING_FAIL_SECOND")
                + "<br>" + qsTranslate("GAPI","STR_VERIFY_PROXY")

            show_error_message(text_top, text_bottom)
        }

        onSignalCacheRemovedLegacy: {
            console.log("Removed Legacy Scap cache files")

            signerror_dialog.propertySignFailDialogTitle.text = qsTranslate("PageServicesSign","STR_SCAP_WARNING")
            var text_top = qsTranslate("PageDefinitionsSCAP","STR_SCAP_LEGACY_CACHE")

            show_error_message(text_top, "")

            // Show button to load attributesText
            closeButtonError.visible = false
            buttonLoadAttr.visible = true
            buttonCancelAttr.visible = true
        }

        onSignalCacheNotReadable: {
            console.log("Scap cache not readable")

            signerror_dialog.propertySignFailDialogTitle.text = qsTranslate("PageDataApp","STR_PERMISSIONS_CACHE")
            var text_top = qsTranslate("PageDataApp","STR_CACHE_NOT_READABLE")

            show_error_message(text_top, "")
        }

        onSignalCanceledSignature: {
            propertyBusyIndicator.running = false
            mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
        }

        onSignalCardAccessError: {
            console.log("Sign Advanced Page onSignalCardAccessError")
            if(cardLoaded){
                var titlePopup = qsTranslate("Popup Card","STR_POPUP_ERROR")
                var bodyPopup = ""
                if (error_code == GAPI.NoReaderFound) {
                    bodyPopup = qsTranslate("Popup Card","STR_POPUP_NO_CARD_READER")
                }
                else if (error_code == GAPI.NoCardFound) {
                    bodyPopup = qsTranslate("Popup Card","STR_POPUP_NO_CARD")
                }
                else if (error_code == GAPI.SodCardReadError) {
                    bodyPopup = qsTranslate("Popup Card","STR_SOD_VALIDATION_ERROR")
                    + "<br/><br/>" + qsTranslate("Popup Card","STR_GENERIC_CARD_ERROR_MSG")
                }
                else if(error_code == GAPI.PinBlocked) {
                    bodyPopup = qsTranslate("Popup Card","STR_POPUP_CARD_PIN_BLOCKED")
                }
                else if (error_code == GAPI.CardUserPinCancel) {
                    bodyPopup = qsTranslate("Popup Card","STR_POPUP_PIN_CANCELED")
                }
                else if (error_code == GAPI.CardPinTimeout) {
                    bodyPopup = qsTranslate("Popup Card","STR_POPUP_PIN_TIMEOUT")
                }
                else if (error_code == GAPI.IncompatibleReader) {
                    bodyPopup = qsTranslate("Popup Card","STR_POPUP_INCOMPATIBLE_READER")
                }
                else {
                    bodyPopup = qsTranslate("Popup Card","STR_POPUP_CARD_ACCESS_ERROR")
                }
                mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)
                if(error_code != GAPI.CardUserPinCancel && error_code != GAPI.CardPinTimeout)
                    cardLoaded = false
            }
            propertyBusyIndicator.running = false
            mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
            propertyButtonAdd.forceActiveFocus()
        }
        onSignalSignCertDataChanged: {
            console.log("Services Sign Advanced --> Certificate Data Changed")

            ownerNameBackup = ownerName
            updateWrappedName()
            if(gapi.getUseNumId() == true){
                propertyPDFPreview.propertyDragSigNumIdText.text =
                        qsTranslate("GAPI","STR_NIC") + ": " + NIC
            } else {
                propertyPDFPreview.propertyDragSigNumIdText.visible = false
            }

            propertyPDFPreview.propertyDragSigDateText.visible = gapi.getUseDate()

            propertyBusyIndicator.running = false
            mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
            propertyButtonAdd.forceActiveFocus()
            cardLoaded = true
        }
        onSignalCardChanged: {
            console.log("Services Sign Advanced onSignalCardChanged")
            var titlePopup = qsTranslate("Popup Card","STR_POPUP_CARD_READ")
            var bodyPopup = ""
            if (error_code == GAPI.ET_CARD_REMOVED) {
                bodyPopup = qsTranslate("Popup Card","STR_POPUP_CARD_REMOVED")
                propertyPDFPreview.propertyDragSigSignedByNameText.text =
                        qsTranslate("PageDefinitionsSignature","STR_CUSTOM_SIGN_BY")
                if(gapi.getUseNumId() == true){
                    propertyPDFPreview.propertyDragSigNumIdText.text =  qsTranslate("GAPI","STR_NIC") + ": "
                } else {
                    propertyPDFPreview.propertyDragSigNumIdText.visible = false
                }

                propertyPDFPreview.propertyDragSigDateText.visible = gapi.getUseDate()

                cardLoaded = false
            }
            else if (error_code == GAPI.ET_CARD_CHANGED) {
                bodyPopup = qsTranslate("Popup Card","STR_POPUP_CARD_CHANGED")
                propertyBusyIndicator.running = true
                cardLoaded = true
                signCertExpired = false

                gapi.startGettingInfoFromSignCert();
                gapi.startCheckSignatureCertValidity();
            }
            else{
                bodyPopup = qsTranslate("Popup Card","STR_POPUP_CARD_READ_UNKNOWN")
                cardLoaded = false
            }
            mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)

        }

        onSignalSignCertExpired: {
            console.log("Services Sign onSignalSignCertExpired")
            var titlePopup = qsTranslate("PageServicesSign", "STR_WARNING")
            var bodyPopup = qsTranslate("PageServicesSign","STR_EXPIRED_SIGN_CERT")
            mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)
            signCertExpired = true
            
            propertyBusyIndicator.running = false
            mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
        }

        onSignalSignCertSuspended: {
            console.log("Services Sign onSignalSignCertRevoked")
            var titlePopup = qsTranslate("PageServicesSign", "STR_WARNING")
            var bodyPopup = qsTranslate("PageServicesSign","STR_SUSPENDED_SIGN_CERT")
            mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)

            propertyBusyIndicator.running = false
            mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
        }

        onSignalSignCertRevoked: {
            console.log("Services Sign onSignalSignCertRevoked")
            var titlePopup = qsTranslate("PageServicesSign", "STR_WARNING")
            var bodyPopup = qsTranslate("PageServicesSign","STR_REVOKED_SIGN_CERT")
            mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)

            propertyBusyIndicator.running = false
            mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
        }

        onSignalCustomSignImageRemoved: {
            console.log("Services Sign onSignalCustomSignImageRemoved")
            var titlePopup = qsTranslate("PageServicesSign", "STR_WARNING")
            var bodyPopup = qsTranslate("PageServicesSign","STR_CUSTOM_IMAGE_REMOVED")
            mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)
        }

        onSignalStartCheckCCSignatureCert: {
            console.log("Services Sign onSignalStartCheckCCSignatureCert")
            propertyBusyIndicator.running = true
            mainFormID.opacity = Constants.OPACITY_POPUP_FOCUS
        }

        onSignalOkSignCertificate: {
            propertyBusyIndicator.running = false
            mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS

            if (gapi.doGetTriesLeftSignPin() === 0) {
                var titlePopup = qsTranslate("Popup PIN", "STR_POPUP_ERROR")
                var bodyPopup = qsTranslate("Popup PIN", "STR_POPUP_CARD_PIN_SIGN_BLOCKED")
                mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)
            } else {
                // If application was started with signAdvanced and output option from command line
                var shortcutOutput = getShortcutOutput()
                if (shortcutOutput) {
                    if (propertyListViewFiles.count == 1) {
                        var inputFile = propertyListViewFiles.model.get(0).fileUrl
                        inputFile = inputFile.substring(inputFile.lastIndexOf('/'), inputFile.length - 1)
                        shortcutOutput = shortcutOutput + Functions.replaceFileSuffix(inputFile, "_signed.pdf")
                    }
                    signCC(shortcutOutput)
                    gapi.setShortcutOutput("")
                    return;
                }

                if(propertySwitchAddAttributes.checked && numberOfAttributesSelected() == 0) {
                    //SCAP switch checked but no attributes selected
                    var titlePopup = qsTranslate("PageServicesSign","STR_SCAP_WARNING")
                    var bodyPopup = qsTranslate("PageServicesSign","STR_SCAP_ATTRIBUTES_NOT_SELECT")
                    mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)
                    return
                }

                var prefix = (Qt.platform.os === "windows" ? "file:///" : "file://");
                if (propertyListViewFiles.count == 1) {
                    propertyFileDialogOutput.title = qsTranslate("Popup File", "STR_POPUP_FILE_OUTPUT")

                    var outputFile = propertyListViewFiles.model.get(0).fileUrl
                    var newSuffix = propertyRadioButtonPADES.checked ? "_signed.pdf" : "_xadessign.asics"

                    if(containsPackageAsic()){
                        var output = decodeURIComponent(Functions.stripFilePrefix(outputFile))
                        signCC(output)
                    } else {
                        propertyFileDialogOutput.currentFile = prefix + Functions.replaceFileSuffix(outputFile, newSuffix)
                        propertyFileDialogOutput.open()
                    }
                }else{
                    if (propertyRadioButtonPADES.checked) {
                        propertyFileDialogBatchOutput.title = qsTranslate("Popup File","STR_POPUP_FILE_OUTPUT_FOLDER")
                        propertyFileDialogBatchOutput.open()
                    } else {
                        if (containsPackageAsic()) {
                            var titlePopup = qsTranslate("PageServicesSign","STR_FILE_ASIC_TITLE")
                            var bodyPopup = qsTranslate("PageServicesSign","STR_FILE_ASIC")
                            mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)
                        } else {
                            var outputFolderPath = propertyListViewFiles.model.get(propertyListViewFiles.count-1).fileUrl
                            if (outputFolderPath.lastIndexOf('/') >= 0)
                                outputFolderPath = outputFolderPath.substring(0, outputFolderPath.lastIndexOf('/'))
                            propertyFileDialogOutput.currentFile = prefix + outputFolderPath + "/xadessign.asice";
                            propertyFileDialogOutput.open()
                        }
                    }
                }
            }
        }
    }
    Connections {   
        target: image_provider_pdf
        onSignalPdfSourceChanged: {
            console.log("Receive signal onSignalPdfSourceChanged pdfWidth = "+pdfWidth+" pdfHeight = "+pdfHeight);
            propertyPDFPreview.propertyPdfOriginalWidth=pdfWidth
            propertyPDFPreview.propertyPdfOriginalHeight=pdfHeight
            propertyPDFPreview.updateSignPreview()
            propertyPDFPreview.updatePageSize()
            propertyPDFPreview.setSignPreview(
                        propertyPageLoader.propertyBackupCoordX * propertyPageLoader.propertyBackupBackgroundWidth,
                        propertyPageLoader.propertyBackupCoordY * propertyPageLoader.propertyBackupBackgroundHeight)

            if (propertyPDFPreview.propertyDragSigRect.height < propertyPDFPreview.propertyDragSigImg.height + propertyPDFPreview.propertyDragSigWaterImg.height) {
                propertyPDFPreview.propertyDragSigImg.visible = false
            }
            else {
                propertyPDFPreview.propertyDragSigImg.visible = true
            }
            propertyPDFPreview.forceActiveFocus()
        }
    }

    Connections {
        target: propertyPDFPreview
        onUpdateSealData: {

            var width = propertyPDFPreview.propertyDragSigRect.width / propertyPDFPreview.propertyPDFWidthScaleFactor / propertyPDFPreview.propertyConvertPtsToPixel
            var height = propertyPDFPreview.propertyDragSigRect.height / propertyPDFPreview.propertyPDFHeightScaleFactor / propertyPDFPreview.propertyConvertPtsToPixel

            // The height of the small signature is half of the height of the current configured signature
            // So we have to double the height to small signature have the height of the preview
            height = propertyCheckSignReduced.checked ? 2 * height : height

            gapi.resizePDFSignSeal(parseInt(width),parseInt(height))

            getFontSize()

            updateWrappedName();
            updateWrappedLocation(propertyTextFieldLocal.text);
            if (propertySwitchAddAttributes.checked) updateSCAPInfoOnPreview();
        }
    }
    Components.DialogCMD{
        id: dialogSignCMD
    }
    Dialog {
        id: signsuccess_dialog
        width: 400
        height: 220
        visible: false
        font.family: lato.name
        modal: true
        closePolicy: Popup.CloseOnEscape

        // Center dialog in the main view
        x: - mainMenuView.width - subMenuView.width
           + mainView.width * 0.5 - signsuccess_dialog.width * 0.5
        y: parent.height * 0.5 - signsuccess_dialog.height * 0.5
        property alias propertySignSuccessDialogText: labelText

        header: Label {
            id: titleText
            text: {
                if(propertyListViewFiles.count > 1) {
                    qsTranslate("PageServicesSign", "STR_SIGN_SUCESS_MULTI")
                } else {
                    qsTranslate("PageServicesSign", "STR_SIGN_SUCESS")
                }
            }
            elide: Label.ElideRight
            padding: 24
            bottomPadding: 0
            font.bold: rectPopUp.activeFocus
            font.pixelSize: Constants.SIZE_TEXT_MAIN_MENU
            color: Constants.COLOR_MAIN_BLUE
        }
        Item {
            id: rectPopUp
            width: signsuccess_dialog.availableWidth
            height: 50

            Keys.enabled: true
            Keys.onPressed: {
                if (event.key===Qt.Key_Enter || event.key===Qt.Key_Return || event.key===Qt.Key_Space) {
                    signSuccessShowSignedFile()
                }
            }
            Accessible.role: Accessible.AlertMessage
            Accessible.name: qsTranslate("Popup Card","STR_SHOW_WINDOWS")
                             + titleText.text + labelText.text + labelOpenText.text
            KeyNavigation.tab: closeButton
            KeyNavigation.down: closeButton
            KeyNavigation.right: closeButton
            KeyNavigation.backtab: openFileButton
            KeyNavigation.up: openFileButton

            Item {
                id: rectLabelText
                width: parent.width
                height: childRect.height
                anchors.horizontalCenter: parent.horizontalCenter
                Text {
                    id: labelText
                    width: parent.width
                    font.bold: activeFocus
                    font.pixelSize: Constants.SIZE_TEXT_LABEL
                    font.family: lato.name
                    color: Constants.COLOR_TEXT_LABEL
                    wrapMode: Text.Wrap
                }

                Text {
                    id: labelOpenText
                    width: parent.width
                    text: (propertyListViewFiles.count > 1 || propertyRadioButtonXADES.checked) ?
                            qsTranslate("PageServicesSign", "STR_SIGN_OPEN_MULTI") :
                            qsTranslate("PageServicesSign", "STR_SIGN_OPEN")

                    font.bold: activeFocus
                    font.pixelSize: Constants.SIZE_TEXT_LABEL
                    font.family: lato.name
                    color: Constants.COLOR_TEXT_LABEL
                    wrapMode: Text.Wrap

                    anchors.top: labelText.text == "" ? parent.top : labelText.bottom
                    anchors.topMargin: labelText.text == "" ? 0 : Constants.SIZE_ROW_V_SPACE
                }
            }
        }
        Item {
            width: signsuccess_dialog.availableWidth
            height: Constants.HEIGHT_BOTTOM_COMPONENT
            y: 100
            Item {
                width: parent.width
                height: Constants.HEIGHT_BOTTOM_COMPONENT
                anchors.horizontalCenter: parent.horizontalCenter
                Button {
                    id: closeButton
                    width: Constants.WIDTH_BUTTON
                    height: Constants.HEIGHT_BOTTOM_COMPONENT
                    text: qsTranslate("Popup File","STR_POPUP_FILE_CANCEL")
                    anchors.left: parent.left
                    font.pixelSize: Constants.SIZE_TEXT_FIELD
                    font.family: lato.name
                    font.capitalization: Font.MixedCase
                    onClicked: {
                        signsuccess_dialog.close()
                        mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: text
                    KeyNavigation.tab: openFileButton
                    KeyNavigation.down: openFileButton
                    KeyNavigation.right: openFileButton
                    KeyNavigation.backtab: rectPopUp
                    KeyNavigation.up: rectPopUp
                    highlighted: activeFocus
                    Keys.onEnterPressed: clicked()
                    Keys.onReturnPressed: clicked()
                }
                Button {
                    id: openFileButton
                    width: Constants.WIDTH_BUTTON
                    height: Constants.HEIGHT_BOTTOM_COMPONENT
                    text: qsTranslate("Popup File","STR_POPUP_FILE_OPEN")
                    anchors.right: parent.right
                    font.pixelSize: Constants.SIZE_TEXT_FIELD
                    font.family: lato.name
                    font.capitalization: Font.MixedCase
                    onClicked: {
                        signSuccessShowSignedFile()
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: text
                    KeyNavigation.tab: rectPopUp
                    KeyNavigation.down: rectPopUp
                    KeyNavigation.right: rectPopUp
                    KeyNavigation.backtab: closeButton
                    KeyNavigation.up: closeButton
                    highlighted: activeFocus
                    Keys.onEnterPressed: clicked()
                    Keys.onReturnPressed: clicked()
                }
            }
        }
        onClosed: {
            mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
            mainFormID.propertyPageLoader.forceActiveFocus()
        }
        onOpened: {
            rectPopUp.forceActiveFocus()
        }
    }

    Dialog {
        id: signerror_dialog
        width: 400
        height: 200
        visible: false
        font.family: lato.name
        modal: true
        closePolicy: Popup.CloseOnEscape

        // Center dialog in the main view
        x: - mainMenuView.width - subMenuView.width
           + mainView.width * 0.5 - signerror_dialog.width * 0.5
        y: parent.height * 0.5 - signerror_dialog.height * 0.5

        property alias propertySignFailDialogTitle: titleTextError
        property alias propertySignFailDialogText: text_sign_error
        property alias propertySignFailDialogGenericText: text_sign_generic_error

        header: Label {
            id: titleTextError
            text: qsTranslate("PageServicesSign","STR_SIGN_FAIL")
            elide: Label.ElideRight
            padding: 24
            bottomPadding: 0
            font.bold: rectPopUpError.activeFocus
            font.pixelSize: Constants.SIZE_TEXT_MAIN_MENU
            color: Constants.COLOR_MAIN_BLUE

        }
        Item {
            id: rectPopUpError
            width: parent.width
            height: parent.height

            Accessible.role: Accessible.AlertMessage
            Accessible.name: qsTranslate("Popup Card","STR_SHOW_WINDOWS")
                             + titleTextError.text + text_sign_error.text + text_sign_generic_error
            KeyNavigation.tab: closeButtonError.visible ? closeButtonError : (buttonCancelAttr.visible ? buttonCancelAttr : buttonLoadAttr)
            KeyNavigation.right: closeButtonError.visible ? closeButtonError : (buttonCancelAttr.visible ? buttonCancelAttr : buttonLoadAttr)
            KeyNavigation.down: closeButtonError.visible ? closeButtonError : (buttonCancelAttr.visible ? buttonCancelAttr : buttonLoadAttr)
            KeyNavigation.backtab: buttonLoadAttr.visible ? buttonLoadAttr : (buttonCancelAttr.visible ? buttonCancelAttr : closeButtonError)
            KeyNavigation.up: buttonLoadAttr.visible ? buttonLoadAttr : (buttonCancelAttr.visible ? buttonCancelAttr : closeButtonError)
            Column{
                spacing: 10
                Text {
                    id: text_sign_error
                    font.pixelSize: Constants.SIZE_TEXT_LABEL
                    font.family: lato.name
                    color: Constants.COLOR_TEXT_LABEL
                    width: rectPopUpError.width
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 3
                }
                Text {
                    id: text_sign_generic_error
                    font.pixelSize: Constants.SIZE_TEXT_LABEL
                    font.family: lato.name
                    color: Constants.COLOR_TEXT_LABEL
                    width: rectPopUpError.width
                    wrapMode: Text.Wrap
                }
            }

        }
        Item {
            width: signerror_dialog.availableWidth
            height: Constants.HEIGHT_BOTTOM_COMPONENT

            anchors.bottom: parent.bottom
            Item {
                width: parent.width
                height: Constants.HEIGHT_BOTTOM_COMPONENT
                anchors.horizontalCenter: parent.horizontalCenter
                Button {
                    id: closeButtonError
                    width: Constants.WIDTH_BUTTON
                    height: Constants.HEIGHT_BOTTOM_COMPONENT
                    text: "OK"
                    visible: true
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: Constants.SIZE_TEXT_FIELD
                    font.family: lato.name
                    font.capitalization: Font.MixedCase
                    onClicked: {
                        signerror_dialog.close()
                        mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: text
                    KeyNavigation.tab: buttonLoadAttr.visible ? buttonLoadAttr : rectPopUpError
                    KeyNavigation.right: buttonLoadAttr.visible ? buttonLoadAttr : rectPopUpError
                    KeyNavigation.down: buttonLoadAttr.visible ? buttonLoadAttr : rectPopUpError
                    KeyNavigation.backtab: rectPopUpError
                    KeyNavigation.up: rectPopUpError
                    highlighted: activeFocus
                    Keys.onEnterPressed: clicked()
                    Keys.onReturnPressed: clicked()
                }
                Button {
                    id: buttonLoadAttr
                    width: Constants.WIDTH_BUTTON
                    height: Constants.HEIGHT_BOTTOM_COMPONENT
                    text: qsTranslate("PageServicesSign","STR_LOAD_SCAP_ATTRIBUTES")
                    visible: false
                    anchors.right: parent.right
                    font.pixelSize: Constants.SIZE_TEXT_FIELD
                    font.family: lato.name
                    font.capitalization: Font.MixedCase
                    onClicked: {
                        mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
                        propertyPageLoader.attributeListBackup = []
                        gapi.startRemovingAttributesFromCache(GAPI.ScapAttrAll)
                        signerror_dialog.close()
                        jumpToDefinitionsSCAP()
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: text
                    KeyNavigation.tab: rectPopUpError
                    KeyNavigation.down: rectPopUpError
                    KeyNavigation.right: rectPopUpError
                    KeyNavigation.backtab: buttonCancelAttr.visible ? buttonCancelAttr : (closeButtonError.visible ? closeButtonError : rectPopUpError)
                    KeyNavigation.up: buttonCancelAttr.visible ? buttonCancelAttr : (closeButtonError.visible ? closeButtonError : rectPopUpError)
                    highlighted: activeFocus
                    Keys.onEnterPressed: clicked()
                    Keys.onReturnPressed: clicked()
                }
                Button {
                    id: buttonCancelAttr
                    width: Constants.WIDTH_BUTTON
                    height: Constants.HEIGHT_BOTTOM_COMPONENT
                    text: qsTranslate("PageServicesSign","STR_POPUP_CANCEL")
                    visible: false
                    anchors.left: parent.left
                    font.pixelSize: Constants.SIZE_TEXT_FIELD
                    font.family: lato.name
                    font.capitalization: Font.MixedCase
                    onClicked: {
                        signerror_dialog.close()
                        mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: text
                    KeyNavigation.tab: buttonLoadAttr.visible ? buttonLoadAttr : rectPopUpError
                    KeyNavigation.right: buttonLoadAttr.visible ? buttonLoadAttr : rectPopUpError
                    KeyNavigation.down: buttonLoadAttr.visible ? buttonLoadAttr : rectPopUpError
                    KeyNavigation.backtab: rectPopUpError
                    KeyNavigation.up: rectPopUpError
                    highlighted: activeFocus
                    Keys.onEnterPressed: clicked()
                    Keys.onReturnPressed: clicked()
                }
            }
        }
        onOpened: {
            rectPopUpError.forceActiveFocus()
        }
        onClosed: {
            //reset title and visible buttons when closing dialog
            titleTextError.text = qsTranslate("PageServicesSign","STR_SIGN_FAIL")
            closeButtonError.visible = true
            buttonLoadAttr.visible = false
            buttonCancelAttr.visible = false

            mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
            mainFormID.propertyPageLoader.forceActiveFocus()
        }
    }
    propertyButtonArrowHelp {
        onClicked: Functions.showHelp(!propertyShowHelp)
    }
    propertyArrowHelpMouseArea {
        onClicked: Functions.showHelp(!propertyShowHelp)
    }

    PropertyAnimation {
        id: expandAnimation
        target: propertyRectHelp
        properties: "height"
        to: Constants.HEIGHT_HELP_EXPANDED
        duration: mainFormID.propertShowAnimation ? Constants.ANIMATION_CHANGE_OPACITY : 0
    }
    PropertyAnimation {
        id: collapseAnimation
        target: propertyRectHelp
        properties: "height"
        to: Constants.HEIGHT_HELP_COLLAPSED
        duration: mainFormID.propertShowAnimation ? Constants.ANIMATION_CHANGE_OPACITY : 0
    }

    propertyButtonArrowOptions {
        onClicked: Functions.showOptions(!propertyShowOptions)
    }
    propertyArrowOptionsMouseArea {
        onClicked: Functions.showOptions(!propertyShowOptions)
    }

    PropertyAnimation {
        id: expandAnimationOptions
        target: propertyItemOptions
        properties: "height"
        to: propertyOptionsHeight
        duration: mainFormID.propertShowAnimation ? Constants.ANIMATION_CHANGE_OPACITY : 0
        onRunningChanged: {
            // Scroll down to see attributes rectangle
            if (!expandAnimationOptions.running
                    && propertyFlickable.contentHeight > propertyFlickable.height){
                propertyFlickable.flick(0, - getMaxFlickVelocity())
            }
        }
    }
    PropertyAnimation {
        id: collapseAnimationOptions
        target: propertyItemOptions
        properties: "height"
        to: 0
        duration: mainFormID.propertShowAnimation ? Constants.ANIMATION_CHANGE_OPACITY : 0
    }

    propertyMouseAreaToolTipPades{
        onEntered: {
            tooltipExitTimer.stop()
            controlToolTip.close()
            controlToolTip.text = qsTranslate("PageServicesSign","STR_SIGN_PDF_FILES")
            controlToolTip.x = propertyRadioButtonPADES.mapToItem(controlToolTip.parent,0,0).x
                    + propertyRadioButtonPADES.width + Constants.SIZE_IMAGE_TOOLTIP * 0.5
                    - controlToolTip.width * 0.5
            controlToolTip.y = propertyRadioButtonPADES.mapToItem(controlToolTip.parent,0,0).y
                    - controlToolTip.height - Constants.SIZE_SPACE_IMAGE_TOOLTIP
            controlToolTip.open()
        }
        onExited: {
            tooltipExitTimer.start()
        }
    }
    propertyMouseAreaToolTipXades{
        onEntered: {
            tooltipExitTimer.stop()
            controlToolTip.close()
            controlToolTip.text = qsTranslate("PageServicesSign","STR_SIGN_PACKAGE")
            controlToolTip.x = propertyRadioButtonXADES.mapToItem(controlToolTip.parent,0,0).x
                    + propertyRadioButtonXADES.width + Constants.SIZE_IMAGE_TOOLTIP * 0.5
                    - controlToolTip.width * 0.5
            controlToolTip.y = propertyRadioButtonXADES.mapToItem(controlToolTip.parent,0,0).y
                    - controlToolTip.height - Constants.SIZE_SPACE_IMAGE_TOOLTIP
            controlToolTip.open()
        }
        onExited: {
            tooltipExitTimer.start()
        }
    }
    propertyMouseAreaToolTipLTV{
        onEntered: {
            tooltipExitTimer.stop()
            controlToolTip.close()
            controlToolTip.text = qsTranslate("PageServicesSign","STR_LTV_TOOLTIP")
            controlToolTip.x = propertyCheckboxLTV.mapToItem(controlToolTip.parent,0,0).x
                    + propertyCheckboxLTV.width + Constants.SIZE_IMAGE_TOOLTIP * 0.5
                    - controlToolTip.width * 0.5
            controlToolTip.y = propertyCheckboxLTV.mapToItem(controlToolTip.parent,0,0).y
                    - controlToolTip.height - Constants.SIZE_SPACE_IMAGE_TOOLTIP
            controlToolTip.open()
        }
        onExited: {
            tooltipExitTimer.start()
        }
    }

    propertyCheckboxLTV {
        onCheckedChanged: {
            propertyPageLoader.propertyBackupAddLTV = propertyCheckboxLTV.checked
        }
        onEnabledChanged: {
            if (!propertyCheckboxLTV.enabled)
                propertyCheckboxLTV.checked = false
        }
    }

    propertyDropArea {

        onEntered: {
            /*console.log("Signature advanced ! You chose file(s): " + drag.urls);*/
            filesArray = drag.urls
            console.log("Num files: "+filesArray.length);
        }
        onDropped: {
            // Update sign preview position variables to be used to send to sdk
            propertyPDFPreview.updateSignPreview()
            propertyPageLoader.propertyBackupCoordX = propertyPDFPreview.propertyDragSigRect.x / propertyPDFPreview.propertyBackground.width
            propertyPageLoader.propertyBackupCoordY = propertyPDFPreview.propertyDragSigRect.y / propertyPDFPreview.propertyBackground.height

            updateUploadedFiles(filesArray)
        }
        onExited: {
            console.log ("onExited");
            filesArray = []
        }
    }
    propertyDropFileArea {
        onEntered: {
            /*console.log("Signature advanced Drop File Area! You chose file(s): " + drag.urls);*/
            filesArray = drag.urls
            console.log("Num files: "+filesArray.length);
        }
        onDropped: {
            updateUploadedFiles(filesArray)
        }
        onExited: {
            console.log ("onExited");
            filesArray = []
        }
    }

    propertyFileDialogOutput {
        onAccepted: {
            var output = propertyFileDialogOutput.file.toString()
            output = decodeURIComponent(Functions.stripFilePrefix(output))
            signCC(output)
        }
    }
    propertyFileDialogCMDOutput {
        onAccepted: {
            signCMD()
        }
    }
    propertyFileDialogBatchCMDOutput {
        onAccepted: {
            signCMD()
        }
    }
    propertyFileDialogBatchOutput {
        onAccepted: {
            var output = propertyFileDialogBatchOutput.folder.toString()
            output = decodeURIComponent(Functions.stripFilePrefix(output))
            signCC(output)
        }
    }

    propertyTextFieldReason{
        onTextChanged: {
            propertyPDFPreview.propertyDragSigReasonText.text = propertyTextFieldReason.text
            propertyPageLoader.propertyBackupReason = propertyTextFieldReason.text
        }
    }
    propertyTextFieldLocal{
        onTextChanged: {
            updateWrappedLocation(propertyTextFieldLocal.text);

            propertyPageLoader.propertyBackupLocal = propertyTextFieldLocal.text
        }
    }

    propertyCheckSignReduced{
        onCheckedChanged: {
            propertyPageLoader.propertyBackupSignReduced = propertyCheckSignReduced.checked
            if(propertyCheckSignReduced.checked){
                if (propertyPDFPreview.propertyPDFHeightScaleFactor > 0) {
                    propertyPDFPreview.propertyDragSigRect.height =
                        propertyPDFPreview.propertySigHeightReducedDefault * propertyPDFPreview.propertyPDFHeightScaleFactor
                    propertyPDFPreview.propertyDragSigRect.width =
                        propertyPDFPreview.propertySigWidthReducedDefault * propertyPDFPreview.propertyPDFWidthScaleFactor
                }
                propertyPDFPreview.propertySigLineHeight = propertyPDFPreview.propertyDragSigRect.height * 0.2
                propertyPDFPreview.propertyDragSigReasonText.visible = false
                propertyPDFPreview.propertyDragSigLocationText.visible = false
                propertyPDFPreview.propertyDragSigReasonText.text = ""
                propertyPDFPreview.propertyDragSigLocationText.text = ""
                propertyPDFPreview.updateSignPreviewSize()
            }else{
                propertyPDFPreview.propertyDragSigRect.height =
                    propertyPDFPreview.propertySigHeightDefault * propertyPDFPreview.propertyPDFHeightScaleFactor
                propertyPDFPreview.propertyDragSigRect.width =
                    propertyPDFPreview.propertySigWidthDefault * propertyPDFPreview.propertyPDFWidthScaleFactor
                propertyPDFPreview.propertySigLineHeight = propertyPDFPreview.propertyDragSigRect.height * 0.1
                propertyPDFPreview.propertyDragSigReasonText.visible = true
                propertyPDFPreview.propertyDragSigLocationText.visible = true
                propertyPDFPreview.propertyDragSigReasonText.text = propertyTextFieldReason.text
                propertyPDFPreview.propertyDragSigLocationText.text = propertyTextFieldLocal.text === "" ? "" :
                    qsTranslate("PageServicesSign", "STR_SIGN_LOCATION") + ": " + propertyTextFieldLocal.text
                propertyPDFPreview.updateSignPreviewSize()
            }
        }
    }
    ListModel {
        id: entityAttributesModel
        onCountChanged: {
            propertyTextAttributesMsg.visible = false
            propertyMouseAreaTextAttributesMsg.enabled = false
            propertyMouseAreaTextAttributesMsg.z = 0
        }
    }
    propertyListViewEntities{
        onFocusChanged: {
            if(propertyListViewEntities.focus)propertyListViewEntities.currentIndex = 0
        }
    }

    Component {
        id: attributeListDelegate
        Rectangle {
            id: container
            width: parent.width
            height: Math.max(entityText.contentHeight + Constants.SIZE_TEXT_V_SPACE, checkboxSel.height)
            Keys.onSpacePressed: {
                checkboxSel.checked = !checkboxSel.checked
            }
            Keys.onTabPressed: {
                focusForward();
                handleKeyPressed(event.key, attributeListDelegate)
            }
            Keys.onDownPressed: {
                focusForward();
                handleKeyPressed(event.key, attributeListDelegate)
            }
            Keys.onBacktabPressed: {
                focusBackward();
                handleKeyPressed(event.key, attributeListDelegate)
            }
            Keys.onUpPressed: {
                focusBackward();
                handleKeyPressed(event.key, attributeListDelegate)
            }

            Component.onCompleted: {
                propertyListViewHeight += height
            }

            color:  propertyListViewEntities.currentIndex === index && propertyListViewEntities.focus
                    ? Constants.COLOR_MAIN_DARK_GRAY : Constants.COLOR_MAIN_SOFT_GRAY

            Accessible.role: Accessible.CheckBox
            Accessible.name: Functions.filterText(entityText.text)
            Accessible.checked: checkboxSel.checked

            CheckBox {
                id: checkboxSel
                font.family: lato.name
                font.pixelSize: Constants.SIZE_TEXT_FIELD
                font.capitalization: Font.MixedCase
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Constants.SIZE_LISTVIEW_SPACING
                padding: 0
                checked: checkBoxAttr
                onCheckedChanged: {
                    entityAttributesModel.get(index).checkBoxAttr = checkboxSel.checked
                    propertyPageLoader.attributeListBackup[index] = checkboxSel.checked
                    updateSCAPInfoOnPreview()
                }
                onFocusChanged: {
                    if(focus) propertyListViewEntities.currentIndex = index
                }
                Keys.forwardTo: container
            }
            Column {
                id: columnItem
                anchors.left: checkboxSel.right
                width: parent.width - checkboxSel.width
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Constants.SIZE_LISTVIEW_SPACING
                Text {
                    id: entityText
                    text: "<b>" + citizenName + "</b> - " + entityName + " - " + attribute
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font.family: lato.name
                    font.pixelSize: Constants.SIZE_TEXT_FIELD
                    font.capitalization: Font.MixedCase
                }
            }
            function focusForward(){
                checkboxSel.focus = true
                if (propertyListViewEntities.currentIndex == propertyListViewEntities.count - 1) {
                    propertyPDFPreview.forceActiveFocus()
                }else{
                    propertyListViewEntities.currentIndex++
                }
            }
            function focusBackward(){
                checkboxSel.focus = true
                if(propertyListViewEntities.currentIndex == 0){
                    propertySwitchAddAttributes.forceActiveFocus()
                }else{
                    propertyListViewEntities.currentIndex--
                }
            }
        }
    }

    propertyMouseAreaTextAttributesMsg{
        onClicked: {
            jumpToDefinitionsSCAP()
        }
    }

    propertySwitchSignTemp{
        onCheckedChanged: {
            propertyPageLoader.propertyBackupTempSign = propertySwitchSignTemp.checked
        }
    }

    propertyCheckSignShow{
        onCheckedChanged: {
            propertyPageLoader.propertyBackupSignShow = propertyCheckSignShow.checked
        }
    }

    propertySwitchAddAttributes {
        onCheckedChanged: {
            propertyPageLoader.propertyBackupSwitchAddAttributes = propertySwitchAddAttributes.checked
            if(propertySwitchAddAttributes.checked){
                propertyBusyIndicator.running = true
                propertyCheckSignReduced.checked = false
                propertyTextAttributesMsg.visible = true
                propertyMouseAreaTextAttributesMsg.enabled = true
                propertyMouseAreaTextAttributesMsg.z = 1
                propertyPDFPreview.propertyDragSigCertifiedByText.visible = true
                propertyPDFPreview.propertyDragSigAttributesText.visible = true
                gapi.startLoadingAttributesFromCache(false)
            }else{
                propertyTextAttributesMsg.visible = false
                propertyMouseAreaTextAttributesMsg.enabled = false
                propertyMouseAreaTextAttributesMsg.z = 0

                entityAttributesModel.clear()
                propertyListViewHeight = 0
                propertyItemOptions.height = propertyOptionsHeight
                propertyPDFPreview.propertyDragSigCertifiedByText.visible = false
                propertyPDFPreview.propertyDragSigAttributesText.visible = false
                propertyPDFPreview.forceActiveFocus()
            }
        }
    }

    propertyFileDialog {

        onAccepted: {
            /*console.log("You chose file(s): " + propertyFileDialog.fileUrls)*/
            console.log("Num files: " + propertyFileDialog.files.length)

            updateUploadedFiles(propertyFileDialog.files)
        }
        onRejected: {
            console.log("Canceled")
        }
    }


    propertyMouseAreaRectMainRigh {
        onClicked: {
            console.log("propertyMouseAreaRectMainRigh clicked")
            propertyFileDialog.visible = true
        }
    }

    propertyMouseAreaItemOptionsFiles {
        onClicked: {
            console.log("propertyMouseAreaItemOptionsFiles clicked")
            propertyFileDialog.visible = true
        }
    }
    propertyButtonAdd {
        onClicked: {
            console.log("propertyButtonAdd clicked")
            propertyFileDialog.visible = true
        }
    }
    propertyButtonRemoveAll {
        onClicked: {
            console.log("Removing all files")
            filesModel.clear()
            propertyPageLoader.propertyBackupfilesModel.clear()
            gapi.closeAllPdfPreviews();
        }
    }

    propertyButtonSignWithCC {
        onClicked: {
            console.log("Sign with CC")

            gapi.startCCSignatureCertCheck();
        }
    }
    propertyButtonSignCMD {
        onClicked: {
            console.log("Sign with CMD" )
            dialogSignCMD.enableConnections()
            if (!gapi.checkCMDSupport()) {
                var titlePopup = qsTranslate("Popup Card","STR_POPUP_ERROR")
                var bodyPopup = qsTranslate("Popup Card","STR_POPUP_NO_CMD_SUPPORT")
                mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)
            }
            else if( propertySwitchAddAttributes.checked && numberOfAttributesSelected() == 0) {
                var titlePopup = qsTranslate("PageServicesSign","STR_SCAP_WARNING")
                var bodyPopup = qsTranslate("PageServicesSign","STR_SCAP_ATTRIBUTES_NOT_SELECT")
                mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)
                return;
            }
            else {
                // If application was started with signAdvanced and output option from command line
                var shortcutOutput = getShortcutOutput()
                gapi.setShortcutOutput("")

                var prefix = (Qt.platform.os === "windows" ? "file:///" : "file://")

                if (propertyListViewFiles.count == 1) {
                    if (shortcutOutput) {
                        var inputFile = propertyListViewFiles.model.get(0).fileUrl
                        inputFile = inputFile.substring(inputFile.lastIndexOf('/'), inputFile.length - 1)
                        shortcutOutput = prefix + shortcutOutput + Functions.replaceFileSuffix(inputFile, "_signed.pdf")
                        propertyFileDialogCMDOutput.file = shortcutOutput
                        propertyFileDialogCMDOutput.accepted()
                        gapi.setShortcutOutput("")
                        return
                    }

                    var outputFile = propertyListViewFiles.model.get(0).fileUrl
                    var newSuffix = propertyRadioButtonPADES.checked ? "_signed.pdf" : "_xadessign.asics"
                    if(containsPackageAsic()){
                        signCMD()
                    } else {
                        propertyFileDialogCMDOutput.title = qsTranslate("Popup File","STR_POPUP_FILE_OUTPUT")
                        propertyFileDialogCMDOutput.currentFile = prefix + Functions.replaceFileSuffix(outputFile, newSuffix)
                        propertyFileDialogCMDOutput.open()
                    }
                } else {
                    if (propertyRadioButtonPADES.checked) {
                        propertyFileDialogBatchCMDOutput.title = qsTranslate("Popup File","STR_POPUP_FILE_OUTPUT_FOLDER")
                        propertyFileDialogBatchCMDOutput.open()
                    } else {
                        if (containsPackageAsic()){
                            var titlePopup = qsTranslate("PageServicesSign","STR_FILE_ASIC_TITLE")
                            var bodyPopup = qsTranslate("PageServicesSign","STR_FILE_ASIC")
                            mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)
                        }else{
                            var outputFolderPath = propertyListViewFiles.model.get(propertyListViewFiles.count-1).fileUrl
                            if (outputFolderPath.lastIndexOf('/') >= 0)
                                outputFolderPath = outputFolderPath.substring(0, outputFolderPath.lastIndexOf('/'))

                            propertyFileDialogCMDOutput.title = qsTranslate("Popup File","STR_POPUP_FILE_OUTPUT")
                            propertyFileDialogCMDOutput.currentFile = prefix + outputFolderPath + "/xadessign.asice";
                            propertyFileDialogCMDOutput.open()
                        }
                    }
                }
            }
        }
    }

    propertyTextSpinBox{
        text: propertySpinBoxControl.textFromValue(propertySpinBoxControl.value, propertySpinBoxControl.locale)
    }

    propertyFileDialog{

        nameFilters: propertyRadioButtonPADES.checked ?
                         [ "PDF document (*.pdf)", "All files (*)" ] :
                         [ "All files (*)" ]
    }

    propertyRadioButtonPADES{
        onCheckedChanged: {
            propertyPageLoader.propertyBackupFormatPades = propertyRadioButtonPADES.checked

            // reload filemodel -> trigers filesModel.onCountChanged signal
            filesModel.clear()
            for (var i = 0; i < propertyPageLoader.propertyBackupfilesModel.count; i++) {
                filesModel.append({ 
                    "fileUrl": propertyPageLoader.propertyBackupfilesModel.get(i).fileUrl,
                    "isASiC": propertyPageLoader.propertyBackupfilesModel.get(i).isASiC
                })
            }

            if (propertyRadioButtonPADES.checked) {
                propertyTextDragMsgListView.text = propertyTextDragMsgImg.text =
                        qsTranslate("PageServicesSign","STR_SIGN_DROP_MULTI")
            } else {
                propertyTextDragMsgImg.text = qsTranslate("PageServicesSign","STR_SIGN_NOT_PREVIEW")
            }
        }
    }

    Component {
        id: listViewFilesDelegate
        Rectangle{
            id: rectlistViewFilesDelegate
            width: parent.width
            height: fileItem.height
            color:  propertyListViewFiles.currentIndex === index
                    ? Constants.COLOR_MAIN_DARK_GRAY : Constants.COLOR_MAIN_SOFT_GRAY

            Keys.onSpacePressed: {
                console.log("Delete file index:" + index);
                var temp = propertyListViewFiles.currentIndex
                removeFileFromList(index)
                if (propertyListViewFiles.currentIndex > 0) {
                    propertyListViewFiles.currentIndex = temp - 1
                }
            }
            Keys.onTabPressed: {
                if(propertyListViewFiles.currentIndex == propertyListViewFiles.count -1){
                    propertyListViewFiles.currentIndex = 0;
                    handleKeyPressed(event.key, "")
                    propertyButtonAdd.forceActiveFocus()
                }else{
                    propertyListViewFiles.currentIndex++
                    handleKeyPressed(event.key, "")
                }
            }

            MouseArea {
                id: mouseAreaFileName
                anchors.fill: parent
                hoverEnabled : true
                onClicked: {
                    propertyListViewFiles.currentIndex = index

                    if (propertyRadioButtonPADES.checked) {
                        var pageCount = gapi.getPDFpageCount(fileUrl)
                        propertyTextSpinBox.maximumLength = maxTextInputLength(pageCount)
                        propertySpinBoxControl.value =
                            propertyCheckLastPage.checked ? pageCount : propertySpinBoxControl.value

                        propertyPDFPreview.propertyBackground.source =
                            "image://pdfpreview_imageprovider/"+ fileUrl + "?page=" + propertySpinBoxControl.value

                        propertyPDFPreview.propertyFileName = Functions.fileBaseName(fileUrl)
                        propertyPDFPreview.propertyDragSigWaterImg.source = "qrc:/images/pteid_signature_watermark.jpg"
                    }
                }
            }

            Item {
                id: fileItem
                width: parent.width
                height: Math.max(fileName.contentHeight, iconRemove.height) + Constants.SIZE_LISTVIEW_IMAGE_SPACE

                Image {
                    id: iconASiCContainer
                    visible: containsPackageAsic() && propertyListViewFiles.count === 1
                    x: Constants.SIZE_LISTVIEW_IMAGE_SPACE * 0.5
                    width: visible ? Constants.SIZE_IMAGE_FILE_REMOVE : 0
                    height: Constants.SIZE_IMAGE_FILE_REMOVE
                    antialiasing: true
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                    source: "../../images/zip.png"
                }

                Text {
                    id: fileName
                    width: parent.width - iconRemove.width - iconASiCContainer.width - 2 * Constants.SIZE_LISTVIEW_IMAGE_SPACE
                    text: fileUrl
                    font.family: lato.name
                    font.pixelSize: Constants.SIZE_TEXT_FIELD
                    verticalAlignment: Text.AlignVCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: iconASiCContainer.visible ? iconASiCContainer.right : parent.left
                    anchors.leftMargin: Constants.SIZE_LISTVIEW_IMAGE_SPACE * 0.5
                    color: Constants.COLOR_TEXT_BODY
                    wrapMode: Text.WrapAnywhere
                }

                Image {
                    id: iconRemove
                    width: Constants.SIZE_IMAGE_FILE_REMOVE
                    height: Constants.SIZE_IMAGE_FILE_REMOVE
                    antialiasing: true
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Constants.SIZE_LISTVIEW_IMAGE_SPACE * 0.5
                    source:  setButtonDeleteIcon()
                    MouseArea {
                        id: mouseAreaIconDelete
                        anchors.fill: parent
                        hoverEnabled : true
                        onClicked: {
                            console.log("Delete file index:" + index);
                            removeFileFromList(index)
                        }
                    }

                    function setButtonDeleteIcon() {
                        if (mouseAreaIconDelete.containsMouse) {
                            if (propertyListViewFiles.currentIndex === index) {
                                return "../../images/remove_file_hover.png"
                            }
                            return "../../images/remove_file_hover_blue.png"
                        }
                        return "../../images/remove_file.png"
                    }
                }
            }
        }
    }

    Component {
        id: asicFilesDelegate
        Rectangle{
            id: rectAsicFilesDelegate
            width: parent.width - Constants.SIZE_ASIC_LISTVIEW_TEXT_OFFSET
            height: fileItemInASiC.height

            x: Constants.SIZE_ASIC_LISTVIEW_TEXT_OFFSET
            color: Constants.COLOR_MAIN_SOFT_GRAY

            Item {
                id: fileItemInASiC
                width: parent.width
                height: Math.max(fileNameInASiC.contentHeight, iconExtract.height) + Constants.SIZE_LISTVIEW_IMAGE_SPACE

                Text {
                    id: fileNameInASiC
                    width: parent.width - iconExtract.width - Constants.SIZE_LISTVIEW_IMAGE_SPACE
                    text: fileUrl
                    x: Constants.SIZE_LISTVIEW_IMAGE_SPACE * 0.5
                    font.family: lato.name
                    font.pixelSize: Constants.SIZE_TEXT_FIELD
                    verticalAlignment: Text.AlignVCenter
                    anchors.verticalCenter: parent.verticalCenter
                    color: Constants.COLOR_TEXT_BODY
                    wrapMode: Text.WrapAnywhere
                }

                Image {
                    id: iconExtract
                    x: fileNameInASiC.width + Constants.SIZE_LISTVIEW_IMAGE_SPACE * 0.5
                    width: Constants.SIZE_IMAGE_FILE_EXTRACT
                    height: Constants.SIZE_IMAGE_FILE_EXTRACT
                    antialiasing: true
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                    source:  mouseAreaIconExtract.containsMouse ?
                                 "../../images/download_hover_blue.png" :
                                 "../../images/download_icon_blue.png"
                    MouseArea {
                        id: mouseAreaIconExtract
                        anchors.fill: parent
                        hoverEnabled : true
                        onClicked: {
                            if (filesModel.count == 1) {
                                var container_path = filesModel.get(0).fileUrl
                                gapi.extractFileFromASiC(container_path, fileNameInASiC.text)
                            }
                        }
                    }
                }
            }
        }
    }

    ListModel {
        id: asicFilesModel
    }

    ListModel {
        id: filesModel

        onCountChanged: {
            console.log("propertyListViewFiles onCountChanged count:"
                        + propertyListViewFiles.count)
            if(filesModel.count === 0) {
                fileLoaded = false
                propertyTextDragMsgImg.visible = true
                propertyPDFPreview.propertyBackground.source = ""
                propertyTextDragMsgListView.text = propertyTextDragMsgImg.text =
                        qsTranslate("PageServicesSign","STR_SIGN_DROP_MULTI")

                if (propertyRadioButtonXADES.checked) {
                    propertyTextDragMsgImg.text = qsTranslate("PageServicesSign","STR_SIGN_NOT_PREVIEW")
                }

                propertyPDFPreview.reset()
                propertyButtonAdd.forceActiveFocus()

                asicFilesModel.clear()
            }
            else {
                fileLoaded = true
                if(propertyRadioButtonPADES.checked){
                    propertyTextDragMsgImg.visible = false
                    // Preview the last file selected
                    var loadedFilePath = filesModel.get(filesModel.count-1).fileUrl
                    propertyListViewFiles.currentIndex = filesModel.count - 1
                    var pageCount = gapi.getPDFpageCount(loadedFilePath)
                    if(pageCount > 0){
                        propertyTextSpinBox.maximumLength = maxTextInputLength(pageCount)
                        if(propertyCheckLastPage.checked==true
                                || propertySpinBoxControl.value > pageCount)
                            propertySpinBoxControl.value = pageCount
                        updateIndicators(pageCount)
                        propertyPDFPreview.propertyBackground.cache = false
                        propertyPDFPreview.propertyBackground.source =
                                "image://pdfpreview_imageprovider/"+loadedFilePath + "?page=" + propertySpinBoxControl.value
                        propertyPDFPreview.propertyFileName = Functions.fileBaseName(loadedFilePath)
                        propertyPDFPreview.propertyDragSigWaterImg.source = "qrc:/images/pteid_signature_watermark.jpg"
                    }else{
                        removeFileFromList(filesModel.count-1)
                        var titlePopup = qsTranslate("PageServicesSign","STR_LOAD_PDF_ERROR")
                        var bodyPopup = ""
                        var link = "https://amagovpt.github.io/docs.autenticacao.gov/user_manual.html#problemas-com-ficheiros-pdf-não-suportados"
                        if (pageCount === Constants.UNSUPPORTED_PDF_ERROR) {
                            console.log("Error loading pdf file")
                            bodyPopup = qsTranslate("PageServicesSign","STR_LOAD_ADVANCED_PDF_ERROR_MSG")
                        }
                        else if (pageCount === Constants.ENCRYPTED_PDF_ERROR) {
                            console.log("Error loading pdf encrypted file")
                            bodyPopup = qsTranslate("PageServicesSign","STR_LOAD_ENCRYPTED_PDF_ERROR_MSG")
                                        + " " + qsTranslate("PageDefinitionsApp", "STR_MORE_INFO")
                                        + "<a href=" + link + ">"
                                        + qsTranslate("PageDefinitionsApp", "STR_HERE") + "</a>."
                        }
                        else if (pageCount === Constants.XFA_FORM_PDF_ERROR) {
                            console.log("Error loading pdf with XFA forms")
                            bodyPopup = qsTranslate("PageServicesSign","STR_LOAD_XFA_FORM_PDF_ERROR_MSG")
                                        + " " + qsTranslate("PageDefinitionsApp", "STR_MORE_INFO")
                                        + "<a href=" + link + ">"
                                        + qsTranslate("PageDefinitionsApp", "STR_HERE") + "</a>."
                        }
                        else {
                            console.log("Generic Error loading pdf file")
                            bodyPopup = qsTranslate("PageServicesSign","STR_LOAD_PDF_ERROR_MSG")
                        }
                        mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false, link)
                    }
                }else{
                    propertyTextDragMsgImg.visible = true
                    if (containsPackageAsic() && filesModel.count == 1) {
                        var asicFilename = filesModel.get(0).fileUrl.toString()
                        var asicFiles = gapi.listFilesInASiC(asicFilename)

                        for (var i = 0; i < asicFiles.length; i++) {
                            asicFilesModel.append({ "fileUrl": asicFiles[i] })
                        }
                    } else {
                        asicFilesModel.clear()
                    }
                }
                propertyListViewFiles.forceActiveFocus()
            }
        }
    }

    propertySpinBoxControl {
        onValueChanged: {
            var loadedFilePath = filesModel.get(propertyListViewFiles.currentIndex).fileUrl
            var maxPageAllowed = propertyCheckLastPage.checked ? gapi.getPDFpageCount(loadedFilePath) : getMinimumPage()
            if(propertySpinBoxControl.value > maxPageAllowed){
                propertySpinBoxControl.value = maxPageAllowed
            }
            propertyPDFPreview.propertyBackground.source =
                    "image://pdfpreview_imageprovider/"+loadedFilePath + "?page=" + propertySpinBoxControl.value
            propertyPageLoader.propertyBackupPage =  propertySpinBoxControl.value
            updateIndicators(maxPageAllowed)
        }
    }
    propertyCheckLastPage {
        onCheckedChanged: {
            var loadedFilePath = filesModel.get(propertyListViewFiles.currentIndex).fileUrl
            propertyPageLoader.propertyBackupLastPage =  propertyCheckLastPage.checked

            if(propertyCheckLastPage.checked){
                propertySpinBoxControl.enabled = false
                propertyPageText.enabled = false
                propertySpinBoxControl.value = gapi.getPDFpageCount(loadedFilePath)
            }
            else{
                propertySpinBoxControl.enabled = true
                propertyPageText.enabled = true
                propertyTextSpinBox.visible = true
                propertySpinBoxControl.value = getMinimumPage()
            }

            propertyPDFPreview.propertyBackground.source =
                "image://pdfpreview_imageprovider/"+ loadedFilePath + "?page=" + propertySpinBoxControl.value
        }
    }

    onIsAnimationFinishedChanged: {
        if(isAnimationFinished == true){
            loadUnfinishedSignature()
        }
    }

    function update_image_on_seal() {
        var urlCustomImage = gapi.getCachePath()+"/CustomSignPicture.jpg"
        if(gapi.getUseCustomSignature() && gapi.customSignImageExist()){
            if (Qt.platform.os === "windows") {
                urlCustomImage = "file:///"+urlCustomImage
            }else{
                urlCustomImage = "file://"+urlCustomImage
            }
            propertyPDFPreview.propertyDragSigImg.source = urlCustomImage
        }else{
            propertyPDFPreview.propertyDragSigImg.source = "qrc:/images/logo_CC_seal.png"
        }
    }

    Component.onCompleted: {
        console.log("Page Services Sign Advanced mainWindowCompleted")
        propertyPageLoader.propertyBackupFromSignaturePage = false
        propertyBusyIndicator.running = true
        update_image_on_seal()

        if (gapi.getShortcutFlag() == GAPI.ShortcutIdSign){
            var paths = gapi.getShortcutPaths()
            for(var i = 0; i < paths.length; i++) {
                paths[i] = gapi.getAbsolutePath(paths[i])
            }
            updateUploadedFiles(paths)

            propertyTextFieldLocal.text = gapi.getShortcutLocation()
            propertyTextFieldReason.text = gapi.getShortcutReason()
            propertySwitchSignTemp.checked = gapi.getShortcutTsa()

            // do not update fields next time (includes input, local, reason, tsa, ...)
            gapi.setShortcutFlag(GAPI.ShortcutIdNone)
        }

        if (!propertyShowHelp)
            propertyRectHelp.height = Constants.HEIGHT_HELP_COLLAPSED
        if (propertyShowOptions)
            propertyItemOptions.height = propertyOptionsHeight

        propertyPDFPreview.propertyDragSigSignedByNameText.text =
            qsTranslate("PageDefinitionsSignature","STR_CUSTOM_SIGN_BY")
        if(gapi.getUseNumId() == true){
            propertyPDFPreview.propertyDragSigNumIdText.text =
                qsTranslate("GAPI","STR_NIC") + ": "
        } else {
            propertyPDFPreview.propertyDragSigNumIdText.visible = false
        }
        propertyPDFPreview.propertyDragSigDateText.visible = gapi.getUseDate()

        signCertExpired = false
        gapi.startGettingInfoFromSignCert();
        gapi.startCheckSignatureCertValidity();
    }
    Component.onDestruction: {
        console.log("PageServicesSignAdvanced destruction")
        if(gapi) {
            gapi.closeAllPdfPreviews();
            gapi.setShortcutOutput("")
        }
    }

    function append_attributes_to_model(attributes) {
        for (var provider in attributes) {
            for (var i = 0; i < attributes[provider].length; i++) {
                //we have to receive the attribut ids in the same array for now...
                // citizen name - attribute [id] "exampleID"
                var attribute_and_id = attributes[provider][i].split("[id]")

                var name_attributes = attribute_and_id[0].split("-")

                entityAttributesModel.append({
                    citizenName: toTitleCase(name_attributes[0]),
                    entityName: provider,
                    attribute: name_attributes[1],
                    id: attribute_and_id[1].trim(),
                    checkBoxAttr: false
                });
            }
        }
    }

    function loadUnfinishedSignature() {
        // Load backup data about unfinished advanced signature
        propertyRadioButtonPADES.checked = propertyPageLoader.propertyBackupFormatPades
        propertyRadioButtonXADES.checked = !propertyPageLoader.propertyBackupFormatPades
        propertySwitchSignTemp.checked = propertyPageLoader.propertyBackupTempSign
        propertyCheckboxLTV.checked= propertyPageLoader.propertyBackupAddLTV
        propertySwitchAddAttributes.checked = propertyPageLoader.propertyBackupSwitchAddAttributes
        propertyCheckSignShow.checked = propertyPageLoader.propertyBackupSignShow
        propertyCheckSignReduced.checked = propertyPageLoader.propertyBackupSignReduced

        filesModel.clear()
        for(var i = 0; i < propertyPageLoader.propertyBackupfilesModel.count; i++)
        {
            if(gapi.fileExists(propertyPageLoader.propertyBackupfilesModel.get(i).fileUrl)){
                filesModel.append({
                                      "fileUrl": propertyPageLoader.propertyBackupfilesModel.get(i).fileUrl,
                                      "isASiC": propertyPageLoader.propertyBackupfilesModel.get(i).isASiC
                                  })
            }
        }

        propertySpinBoxControl.value = propertyPageLoader.propertyBackupPage
        propertyCheckLastPage.checked = propertyPageLoader.propertyBackupLastPage
        propertyTextFieldReason.text = propertyPageLoader.propertyBackupReason
        propertyTextFieldLocal.text = propertyPageLoader.propertyBackupLocal
        propertyPDFPreview.setSignPreview(propertyPageLoader.propertyBackupCoordX * propertyPDFPreview.propertyBackground.width,propertyPageLoader.propertyBackupCoordY * propertyPDFPreview.propertyBackground.height)


        propertyTextDragMsgListView.text = propertyTextDragMsgImg.text =
                qsTranslate("PageServicesSign","STR_SIGN_DROP_MULTI")
    }

    function getMinimumPage(){
        // Function to detect minimum number of pages of all loaded pdfs to sign
        var minimumPage = 0
        for(var i = 0 ; i < filesModel.count ; i++ ){
            var loadedFilePath = filesModel.get(i).fileUrl
            var pageCount = gapi.getPDFpageCount(loadedFilePath)
            if(minimumPage == 0 || pageCount < minimumPage)
                minimumPage = pageCount

            /*console.log("loadedFilePath: " + loadedFilePath + " page count: " + pageCount
                        + "minimum: " + minimumPage)*/
        }
        return minimumPage
    }

    function updateIndicators(pageCount){
        propertySpinBoxControl.up.indicator.visible = true
        propertySpinBoxControl.down.indicator.visible = true
        propertySpinBoxControl.up.indicator.enabled = true
        propertySpinBoxControl.down.indicator.enabled = true

        if(propertySpinBoxControl.value === pageCount
                || propertySpinBoxControl.value === getMinimumPage()){
            propertySpinBoxControl.up.indicator.visible = false
            propertySpinBoxControl.up.indicator.enabled = false
        }
        if (propertySpinBoxControl.value === 1){
            propertySpinBoxControl.down.indicator.visible = false
            propertySpinBoxControl.down.indicator.enabled = false
        }
    }
    function signSuccessShowSignedFile(){
        signsuccess_dialog.close()
        if (Functions.openSignedFiles() == false){

            var titlePopup =  propertyListViewFiles.count > 1 || propertyRadioButtonXADES.checked == 1
                ? qsTranslate("PageServicesSign","STR_SIGN_OPEN_ERROR_TITLE_MULTI") + controler.autoTr
                : qsTranslate("PageServicesSign","STR_SIGN_OPEN_ERROR_TITLE") + controler.autoTr

            var bodyPopup = propertyListViewFiles.count > 1 || propertyRadioButtonXADES.checked == 1
                ? qsTranslate("PageServicesSign","STR_SIGN_OPEN_ERROR_MULTI") + controler.autoTr
                : qsTranslate("PageServicesSign","STR_SIGN_OPEN_ERROR") + controler.autoTr

            mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)
        }
    }
    function toTitleCase(str) {
        return str.replace(/\w\S*/g, function(txt){
            return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
        });
    }
    function onlyUnique(value, index, self) {
        return self.indexOf(value) === index;
    }
    //should only used by a fileModel list because it uses .count instead of .length
    function containsFile(obj, list) {
        var i;
        for (i = 0; i < list.count; i++) {
            if (list.get(i).fileUrl.toString() === obj.fileUrl) {
                console.log("File already uploaded");
                return true;
            }
        }
        return false;
    }
    function appendFileToModel(path) {
        var alreadyUploaded = false;
        var newFileUrl = {
            "fileUrl": path,
            "isASiC" : propertyRadioButtonXADES.checked ? fileIsAsic(path) : false
        };

        if (!containsFile(newFileUrl, propertyPageLoader.propertyBackupfilesModel)){
            propertyPageLoader.propertyBackupfilesModel.append(newFileUrl);
            filesModel.append(newFileUrl);
        } else {
            alreadyUploaded = true;
        }
        return alreadyUploaded;
    }

    function containsPackageAsic() {
        for (var i = 0; i < filesModel.count; i++) {
            if (filesModel.get(i).isASiC) {
                return true;
            }
        }
        return false;
    }

    function fileIsAsic(fileUrl) {
        return gapi.isASiC(fileUrl.toString())
    }

    function updateUploadedFiles(fileList) {
        for (var i = 0; i < fileList.length; i++) {
            var path = decodeURIComponent(Functions.stripFilePrefix(fileList[i]));

            if (gapi.isFile(path)) {

                // XAdES related checks should only be done if XAdES configuration is enabled
                if (propertyRadioButtonXADES.checked) {
                    if (fileIsAsic(path) && filesModel.count > 0) { 
                        // asic container must be the only file on the list - warning
                        var titlePopup = qsTranslate("PageServicesSign","STR_FILE_ASIC_TITLE")
                        var bodyPopup = qsTranslate("PageServicesSign","STR_FILE_ASIC_ONLY_FILE")
                        mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)
                        return
                    } else if (containsPackageAsic()) {
                        // asic container already on the list - warning
                        var titlePopup = qsTranslate("PageServicesSign","STR_FILE_ASIC_TITLE")
                        var bodyPopup = qsTranslate("PageServicesSign","STR_FILE_ASIC_ALREADY_ON_LIST")
                        mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)
                        return
                    } 
                }

                var fileAlreadyUploaded = appendFileToModel(path);
                if (fileAlreadyUploaded) {
                    // file already uploaded - error
                    var titlePopup = qsTranslate("PageServicesSign","STR_FILE_UPLOAD_FAIL")
                    var bodyPopup = qsTranslate("PageServicesSign","STR_FILE_ALREADY_UPLOADED")
                    mainFormID.propertyPageLoader.activateGeneralPopup(titlePopup, bodyPopup, false)
                }
                
            } else if (gapi.isDirectory(path)) {
                var filesInDir = gapi.getFilesFromDirectory(path);
                if (filesInDir instanceof Array) {
                    updateUploadedFiles(filesInDir); // it's a folder do it again recursively
                }
            }
        }
    }

    function maxTextInputLength(num){
        //given number of pages returns maximum length that TextInput should accept
        return Math.ceil(Math.log(num + 1) / Math.LN10);
    }

    function numberOfAttributesSelected() {
        var count = 0
        for (var i = 0; i < entityAttributesModel.count; i++){
            if(entityAttributesModel.get(i).checkBoxAttr == true){
                count++
            }
        }
        return count
    }

    function jumpToDefinitionsSCAP(){
        propertyPageLoader.propertyBackupFromSignaturePage = true
        // Jump to Menu Definitions - PageDefinitionsSCAP
        mainFormID.state = Constants.MenuState.NORMAL
        mainFormID.propertySubMenuListView.model.clear()
        for(var i = 0; i < mainFormID.propertyMainMenuBottomListView.model.get(0).subdata.count; ++i) {
            /*console.log("Sub Menu indice " + i + " - "
                        + mainFormID.propertyMainMenuBottomListView.model.get(0).subdata.get(i).subName);*/
            mainFormID.propertySubMenuListView.model
            .append({
                        "subName": qsTranslate("MainMenuBottomModel",
                                               mainFormID.propertyMainMenuBottomListView.model.get(0).subdata.get(i).subName),
                        "expand": mainFormID.propertyMainMenuBottomListView.model.get(0).subdata.get(i)
                        .expand,
                        "url": mainFormID.propertyMainMenuBottomListView.model.get(0).subdata.get(i)
                        .url
                    })
        }
        mainFormID.propertyMainMenuListView.currentIndex = -1
        mainFormID.propertyMainMenuBottomListView.currentIndex = 0
        mainFormID.propertySubMenuListView.currentIndex = 1
        mainFormID.propertyPageLoader.source = "/contentPages/definitions/PageDefinitionsSCAP.qml"
    }
    function toggleSwitch(element) {
        element.checked = !element.checked
    }
    function toggleRadio(element) {
        if(!element.checked)
            element.checked = true
    }

    function signCC(outputFile) {
        propertyBusyIndicator.running = true
        mainFormID.opacity = Constants.OPACITY_POPUP_FOCUS

        var isTimestamp = propertySwitchSignTemp.checked
        var isLTV = propertyCheckboxLTV.checked
        if (propertyRadioButtonPADES.checked) {
            var page = propertySpinBoxControl.value
            var reason = propertyTextFieldReason.text
            var location = propertyTextFieldLocal.text
            var isSmallSignature = propertyCheckSignReduced.checked
            var isLastPage = propertyCheckLastPage.checked
            var coord_x = -1
            var coord_y = -1
            if(propertyCheckSignShow.checked){
                propertyPDFPreview.updateSignPreview()
                coord_x = propertyPDFPreview.propertyCoordX
                //coord_y must be the lower left corner of the signature rectangle
                coord_y = propertyPDFPreview.propertyCoordY
            }

            /*console.log("Output filename: " + outputFile)*/
            console.log("Signing in position coord_x: " + coord_x
                        + " and coord_y: " + coord_y + " page: " + page + " timestamp: " + isTimestamp + " ltv: " + isLTV + " lastPage: " + isLastPage)

            propertyOutputSignedFile = outputFile;

            if (propertySwitchAddAttributes.checked) {
                var batchFilesArray = []
                for (var i = 0; i < propertyListViewFiles.count; i++) {
                    batchFilesArray[i] =  propertyListViewFiles.model.get(i).fileUrl;
                }
                batchFilesArray = batchFilesArray.filter(onlyUnique);

                var attributeList = getSelectedAttributesIds()

                gapi.startSigningSCAP(batchFilesArray, outputFile, page, coord_x, coord_y,
                    location, reason, isTimestamp, isLTV, isLastPage, attributeList)
            } else {
                if (propertyListViewFiles.count == 1) {
                    var loadedFilePath = propertyListViewFiles.model.get(0).fileUrl
                    gapi.startSigningPDF(loadedFilePath, outputFile, page, coord_x, coord_y,
                        reason, location, isTimestamp, isLTV, isSmallSignature)
                } else {
                    var batchFilesArray = []
                    for (var i = 0; i < propertyListViewFiles.count; i++) {
                        batchFilesArray[i] =  propertyListViewFiles.model.get(i).fileUrl;
                    }

                    batchFilesArray = batchFilesArray.filter(onlyUnique);
                    gapi.startSigningBatchPDF(batchFilesArray, outputFile, page, coord_x, coord_y,
                        reason, location, isTimestamp, isLTV, isSmallSignature, isLastPage)
                }
            }
        }
        else {  //XAdES signature
            propertyOutputSignedFile = outputFile;
            propertyOutputSignedFile =
                    propertyOutputSignedFile.substring(0, propertyOutputSignedFile.lastIndexOf('/'))
            if (propertyListViewFiles.count == 1){
                var loadedFilePath = propertyListViewFiles.model.get(0).fileUrl
                gapi.startSigningXADES(loadedFilePath, outputFile, isTimestamp, isLTV, containsPackageAsic())
            }else{
                var batchFilesArray = []
                for(var i = 0; i < propertyListViewFiles.count; i++){
                    batchFilesArray[i] =  propertyListViewFiles.model.get(i).fileUrl;
                }
                gapi.startSigningBatchXADES(batchFilesArray, outputFile, isTimestamp, isLTV)
            }
        }
    }

    function signCMD() {
        propertyBusyIndicator.running = true
        mainFormID.opacity = Constants.OPACITY_POPUP_FOCUS

        var isTimestamp = false
        if (typeof propertySwitchSignTemp !== "undefined")
            isTimestamp = propertySwitchSignTemp.checked

        var isLTV = false
        if (typeof propertyCheckboxLTV !== "undefined")
            isLTV = propertyCheckboxLTV.checked

        dialogSignCMD.setSignSingleFile(filesModel.count == 1)

        var outputFile = ""
        if (dialogSignCMD.isSignSingleFile() || propertyRadioButtonXADES.checked) {
            if(containsPackageAsic()){
                var prefix = (Qt.platform.os === "windows" ? "file:///" : "file://")
                var outputFile = propertyListViewFiles.model.get(0).fileUrl
                var newSuffix = propertyRadioButtonPADES.checked ? "_signed.pdf" : "_xadessign.asics"
                outputFile = prefix + Functions.replaceFileSuffix(outputFile, newSuffix)
            } else {
                outputFile = propertyFileDialogCMDOutput.file.toString()
            }
        } else {
            outputFile = propertyFileDialogBatchCMDOutput.folder.toString()
        }
        outputFile = decodeURIComponent(Functions.stripFilePrefix(outputFile))

        if (propertyRadioButtonPADES.checked) {
            var loadedFilePaths = []
            for (var fileIndex = 0; fileIndex < filesModel.count; fileIndex++) {
                loadedFilePaths.push(filesModel.get(fileIndex).fileUrl)
            }

            var page = propertySpinBoxControl.value
            var isLastPage = propertyCheckLastPage.checked

            var reason = ""
            if (typeof propertyTextFieldReason !== "undefined")
                reason = propertyTextFieldReason.text

            var location = ""
            if (typeof propertyTextFieldLocal !== "undefined")
                location = propertyTextFieldLocal.text

            var isSmallSignature = false
            if (typeof propertyCheckSignReduced !== "undefined")
                isSmallSignature = propertyCheckSignReduced.checked

            propertyPDFPreview.updateSignPreview()
            var coord_x = -1
            var coord_y = -1
            if (typeof propertyCheckSignShow !== "undefined") {
                if (propertyCheckSignShow.checked) {
                    coord_x = propertyPDFPreview.propertyCoordX
                    //coord_y must be the lower left corner of the signature rectangle
                    coord_y = propertyPDFPreview.propertyCoordY
                }
            } else {
                coord_x = propertyPDFPreview.propertyCoordX
                //coord_y must be the lower left corner of the signature rectangle
                coord_y = propertyPDFPreview.propertyCoordY
            }

            propertyOutputSignedFile = outputFile

            if (typeof propertySwitchAddAttributes !== "undefined" && propertySwitchAddAttributes.checked) {
                var attributeList = getSelectedAttributesIds()
                gapi.signScapWithCMD(loadedFilePaths, outputFile, attributeList, page, coord_x,
                     coord_y, reason, location, isTimestamp, isLTV, isLastPage)
            } else {
                gapi.signCMD(loadedFilePaths, outputFile, page, coord_x, coord_y, reason, location, isTimestamp,
                    isLTV,isSmallSignature, isLastPage)
            }
        } else {
            propertyOutputSignedFile = outputFile;
            propertyOutputSignedFile =
                propertyOutputSignedFile.substring(0, propertyOutputSignedFile.lastIndexOf('/'))

            var inputFiles = []
            for (var i = 0; i < propertyListViewFiles.count; i++) {
                inputFiles[i] = propertyListViewFiles.model.get(i).fileUrl;
            }

            gapi.startSigningXADESWithCMD(inputFiles, outputFile, isTimestamp, isLTV, containsPackageAsic())
        }
    }

    function getShortcutOutput() {
        var output = gapi.getShortcutOutput()
        if (output == "")
            return null
        output = gapi.getAbsolutePath(output)
        if (output.charAt(output.length - 1) != "/") {
            output += "/"
        }
        return output
    }
    function handleKeyPressed(key, callingObject){
        var direction = getDirection(key)
        switch(direction){
        case Constants.DIRECTION_UP:
            if(callingObject === propertyTitleHelp && !propertyFlickable.atYEnd){
                propertyFlickable.flick(0, - getMaxFlickVelocity())
            }
            else if(callingObject === attributeListDelegate
                    && !propertyFlickable.atYBeginning){
                propertyFlickable.flick(0, Constants.FLICK_Y_VELOCITY_ATTR_LIST);
            }
            else if(!propertyFlickable.atYBeginning)
                propertyFlickable.flick(0, Constants.FLICK_Y_VELOCITY)
            break;

        case Constants.DIRECTION_DOWN:
            if(callingObject === propertyRadioButtonXADES
                    && !fileLoaded
                    && !propertyFlickable.atYBeginning){
                propertyFlickable.flick(0, getMaxFlickVelocity());
            }
            else if(callingObject === propertyButtonSignWithCC
                    && !propertyButtonSignCMD.enabled
                    && !propertyFlickable.atYBeginning){
                propertyFlickable.flick(0, getMaxFlickVelocity());
            }
            else if(callingObject === propertyButtonSignCMD
                    && !propertyFlickable.atYBeginning){
                propertyFlickable.flick(0, getMaxFlickVelocity());
            }
            else if(callingObject === propertyListViewEntities
                    && !propertyFlickable.atYBeginning){
                propertyFlickable.flick(0, getMaxFlickVelocity());
            }
            else if(callingObject === attributeListDelegate
                    && !propertyFlickable.atYEnd){
                propertyFlickable.flick(0, - Constants.FLICK_Y_VELOCITY_ATTR_LIST);
            }
            else if(!propertyFlickable.atYEnd)
                propertyFlickable.flick(0, - Constants.FLICK_Y_VELOCITY)
            break;
        }
    }
    function getDirection(key){
        var direction = Constants.NO_DIRECTION;
        if (key == Qt.Key_Backtab || key == Qt.Key_Up || key == Qt.Key_Left){
            direction = Constants.DIRECTION_UP;
        }
        else if (key == Qt.Key_Tab || key == Qt.Key_Down || key == Qt.Key_Right){
            direction = Constants.DIRECTION_DOWN;
        }
        return direction;
    }
    function updateWrappedName(){
        var isSCAP = (propertySwitchAddAttributes.checked && numberOfAttributesSelected() != 0);
        
        var wrappedName = gapi.getWrappedText(ownerNameBackup, 
            isSCAP ? Constants.NAME_SCAP_MAX_LINES : Constants.NAME_MAX_LINES, Constants.SEAL_NAME_OFFSET)
        propertyPDFPreview.propertyDragSigSignedByNameText.text = qsTranslate("PageDefinitionsSignature","STR_CUSTOM_SIGN_BY") + " <b>" +
            wrappedName.join("<br>") + "</b>";
    }

    function updateWrappedLocation(text){
        var wrappedName = gapi.getWrappedText(text, Constants.LOCATION_MAX_LINES, Constants.SEAL_LOCATION_OFFSET)

        propertyPDFPreview.propertyDragSigLocationText.text = propertyTextFieldLocal.text === "" ? "" :
            qsTranslate("PageServicesSign", "STR_SIGN_LOCATION") + ": " + wrappedName.join("<br>");
    }
    function getMaxFlickVelocity(){
        // use visible area of flickable object to calculate
        // a smooth flick velocity
        return 200 + Constants.FLICK_Y_VELOCITY_MAX * (1 - propertyFlickable.visibleArea.heightRatio)
    }

    function removeFileFromList(index){
        gapi.closePdfPreview(filesModel.get(index).fileUrl);
        for(var i = 0; i < propertyPageLoader.propertyBackupfilesModel.count; i++)
        {
            if(propertyPageLoader.propertyBackupfilesModel.get(i).fileUrl
                    === filesModel.get(index).fileUrl)
                propertyPageLoader.propertyBackupfilesModel.remove(index)
        }
        filesModel.remove(index)
    }
    function updateSCAPInfoOnPreview(){
        propertyPDFPreview.propertyDragSigCertifiedByText.text =
            qsTranslate("PageServicesSign","STR_SCAP_CERTIFIED_BY")
        propertyPDFPreview.propertyDragSigAttributesText.text =
            qsTranslate("PageServicesSign","STR_SCAP_CERTIFIED_ATTRIBUTES")

        var attrList = getSelectedAttributesIds()

        if (attrList != []) {
            var attributesToWrap = gapi.getSCAPAttributesText(attrList)

            var entitiesText = attributesToWrap[0]
            var attributesText = attributesToWrap[1]

            ownerEntitiesBackup = entitiesText
            ownerAttrBackup = attributesText

            getFontSize()

            var entities = gapi.getWrappedText(entitiesText, Constants.PROVIDER_SCAP_MAX_LINES, Constants.SEAL_PROVIDER_NAME_OFFSET)
            var attributes = gapi.getWrappedText(attributesText, Constants.ATTR_SCAP_MAX_LINES, Constants.SEAL_ATTR_NAME_OFFSET)
            var fontSize = attributesToWrap[2]

            propertyPDFPreview.propertyDragSigCertifiedByText.text += " <b>" + entities.join("<br>") + "</b>";
            propertyPDFPreview.propertyDragSigAttributesText.text += " <b>" + attributes.join("<br>") + "</b>";
            propertyPDFPreview.propertyCurrentAttrsFontSize = fontSize

            var scap_logo = gapi.getSCAPProviderLogo(attrList)
            if (scap_logo.length != 0) {
                propertyPDFPreview.propertyDragSigImg.source = "file:///" + scap_logo
            } else {
                update_image_on_seal()
            }
        }
    }

    function getSelectedAttributesIds() {
        var attributeList = []
        for (var i = 0; i < entityAttributesModel.count; i++) {
            if (entityAttributesModel.get(i).checkBoxAttr) {
                attributeList.push(entityAttributesModel.get(i).id)
            }
        }

        return attributeList
    }

    function getFontSize() {       
         
        var reason = propertyTextFieldReason.text
        var name = ownerNameBackup
        var nic = gapi.getUseNumId()
        var date = gapi.getUseDate()
        var location = propertyTextFieldLocal.text
        var entities = ownerEntitiesBackup
        var attributes = ownerAttrBackup
        var isReduced = propertyCheckSignReduced.checked
        var width = propertyPDFPreview.propertyDragSigRect.width / propertyPDFPreview.propertyPDFWidthScaleFactor / propertyPDFPreview.propertyConvertPtsToPixel
        var height = propertyPDFPreview.propertyDragSigRect.height / propertyPDFPreview.propertyPDFHeightScaleFactor / propertyPDFPreview.propertyConvertPtsToPixel

        //console.log("getFontSize(" + isReduced + " , " + reason + " , " + name + " , " + nic + " , " + date + " , " + location 
        //        + " , " + entities + " , " + attributes + " , " + width + " , " + height + ")")

        propertyPDFPreview.propertyFontSize = 
                gapi.getSealFontSize(isReduced, reason, name, nic, date, location, 
                entities, attributes, width, height)

        propertyPDFPreview.propertyFontMargin = 
                propertyPDFPreview.propertyFontSize  > 5 ? 1 : 0  
    }

    function show_error_message(text, generic_text) {
        signerror_dialog.propertySignFailDialogText.text = text
        signerror_dialog.propertySignFailDialogGenericText.text = generic_text

        dialogSignCMD.close()
        signerror_dialog.visible = true
        propertyBusyIndicator.running = false
        mainFormID.opacity = Constants.OPACITY_MAIN_FOCUS
        propertyOutputSignedFile = ""
    }
}
