import { LightningElement, api, track, wire } from 'lwc';

import {CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { publish, subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import accountChangeChannel from '@salesforce/messageChannel/XC_AccountChange__c';
import addItemsToCart from '@salesforce/apex/XC_CartController.addItemsToCart';
import getProductAggregates from '@salesforce/apex/XC_LWC_PDPController.getProductAggregates';
import recommendSizeRun from '@salesforce/apex/XC_SizeRunRecommendationService.recommendForPdp';
import adjustRecommendation from '@salesforce/apex/XC_SizeRunRecommendationService.adjustRecommendation';
import saveRecommendation from '@salesforce/apex/XC_SizeRunRecommendationService.saveRecommendation';
import deleteRecommendation from '@salesforce/apex/XC_SizeRunRecommendationService.deleteRecommendation';
import getCampaignInfo from '@salesforce/apex/XC_CampaignLandingPageController.getCampaignInfoPLP';
import getSizeTemplateSizes from '@salesforce/apex/XC_ProductUtil.getSizeTemplateSizes';
import { loadStyle } from 'lightning/platformResourceLoader';
import B2BFPsearchCardCSS from '@salesforce/resourceUrl/B2BFPsearchCardCSS';
import refreshNotifications from '@salesforce/messageChannel/XC_RefreshNotifications__c';
import toast from 'lightning/toast';
import getCustomColorMtd from '@salesforce/apex/XC_LWC_PLPController.getCustomColorMtd';
import b2bTheme from '@salesforce/resourceUrl/b2bTheme';
import b2BMultiResource from '@salesforce/resourceUrl/b2bMultiImg';
import { extractImageUrl } from 'c/productMediaResolver';
import currency from '@salesforce/i18n/currency';

 export default class XcProductDetailsSizeDisplay extends LightningElement {
    @wire(MessageContext) messageContext;

     @api productId;
     _effectiveAccountId;
     _accountChangeSubscription = null;

     @api
     get effectiveAccountId() {
         return this._effectiveAccountId;
     }
     set effectiveAccountId(value) {
         const prev = this._effectiveAccountId;
         this._effectiveAccountId = value || null;
         if (prev !== this._effectiveAccountId && this.loaded) {
             this.getCampaignCategoryTree();
         }
     }
     @api displayableProduct;
     @api sizeRunOptions = [];
     @api noPrice = false;
     @track showInventory = true;
     @track sizeTemplateSizes;
     _addInFlight = false;
     @track productAggregates;
     @track _sizeSurfaceReady = false;
     @track recommendationAmount;
     @track recommendation;
     @track recommendationError;
     @track isRecommending = false;
     @track showRecommendationDialog = false;
     @track selectedRecommendationTemplate = 'AUTO';
     @track isAgentPanelExpanded = false;
     @track agentPrompt = '';
     @track isAgentSending = false;
     @track agentError = '';
     @track agentPreview;
     @track savedRecommendationName = '';
     @track saveAvailableToAllUsers = false;
     @track isSavingRecommendation = false;
     @track saveRecommendationError = '';
     @track saveRecommendationMessage = '';
     @track selectedSavedSizeRunValue = '';
     @track selectedSavedSizeRunKey = '';
     @track localSavedSizeRunOptions = [];
     @track isDeletingRecommendation = false;
     @track agentMessages = [
        {
            key: 'assistant-initial',
            label: 'Assistant',
            text: 'I can explain how this form works, answer size-run questions, or preview changes by row number, exact quantities, budget, size curve, or size bias.',
            className: 'agentMessage agentMessage--assistant'
        }
     ];

     _sizeRevealScheduled = false;
     _agentMessageIndex = 0;
     loaded = false;
     campaignId = null;
    _currentPageReference;
    sortedSizes;
    @wire(CurrentPageReference)
    receivePageReference(result) {
        // Store the response for later use, as needed
        this._currentPageReference = result;
        // Now you can perform your logic
        if (this._currentPageReference.state.campaign) {
            this.campaignId = this._currentPageReference.state.campaign;
            this.getCampaignCategoryTree();
        }
    }

    get b2bMultiImg() {
        return b2BMultiResource;
    }

    b2bRedSwatch = b2bTheme + '/b2bTheme/images/b2bRedSwatch.png';
    b2bPinkSwatch = b2bTheme + '/b2bTheme/images/b2bPinkSwatch.png';
    b2bOrangeSwatch = b2bTheme + '/b2bTheme/images/b2bOrangeSwatch.png';
    b2bYellowSwatch = b2bTheme + '/b2bTheme/images/b2bYellowSwatch.png';
    b2bGreenSwatch = b2bTheme + '/b2bTheme/images/b2bGreenSwatch.png';
    b2bBlueSwatch = b2bTheme + '/b2bTheme/images/b2bBlueSwatch.png';
    b2bPurpleSwatch = b2bTheme + '/b2bTheme/images/b2bPurpleSwatch.png';
    b2bBrownSwatch = b2bTheme + '/b2bTheme/images/b2bBrownSwatch.png';
    b2bBlackSwatch = b2bTheme + '/b2bTheme/images/b2bBlackSwatch.png';
    b2bGreySwatch = b2bTheme + '/b2bTheme/images/b2bGreySwatch.png';
    b2bWhiteSwatch = b2bTheme + '/b2bTheme/images/b2bWhiteSwatch.png';
    colorToPrimaryColorMap = new Map();
    colorMap = new Map();
    colorList = [];

    @wire(getCustomColorMtd, {})
    getCustomColorMtd({ error, data }) {
      if (data) {
        this.colorList = data;
        let nameArray = [];

        this.colorList.forEach((color) => {
            this.colorToPrimaryColorMap.set(color.Label, color.Primary_Color__c);
            nameArray.push(color.Label);
            if(color.Primary_Color__c != null && this.colorMap.get(color.Primary_Color__c) == null){
                let mtdList = [];
                mtdList.push(color.Label);
                this.colorMap.set(color.Primary_Color__c, mtdList);
            }
            else if(color.Primary_Color__c != null){
                let mtdList = this.colorMap.get(color.Primary_Color__c);
                mtdList.push(color.Label);
                this.colorMap.set(color.Primary_Color__c, mtdList);
            }

            if(color.Secondary_Color__c != null && this.colorMap.get(color.Secondary_Color__c) == null){
                let mtdList = [];
                mtdList.push(color.Label);
                this.colorMap.set(color.Secondary_Color__c, mtdList);
            }
            else if(color.Secondary_Color__c != null && !this.colorMap.get(color.Secondary_Color__c).includes(color.Label)){
                let mtdList = this.colorMap.get(color.Secondary_Color__c);
                mtdList.push(color.Label);
                this.colorMap.set(color.Secondary_Color__c, mtdList);
            }
        });
        }
    }


     get items(){
         //console.log("aggregates: " + JSON.stringify(this.productAggregates));
         let itemsToAddToCart = {};
         if(this.productAggregates){
            for(const rowValue of this.productAggregates.rowValues){
                for(const item of rowValue.keyMap){
                    if(item.cellQty > 0){
                        itemsToAddToCart[item.prodId] = {
                            quantity: String(item.cellQty),
                            price: (item.price != null && item.price !== undefined && !isNaN(parseFloat(item.price))) ? String(item.price) : '0',
                            inventoryItemId: item.inventoryItemId || null
                        };
                    }
                }
            }
         }
         return itemsToAddToCart;
     }

    connectedCallback() {
        if (
            typeof window !== 'undefined' &&
            window.matchMedia &&
            window.matchMedia('(prefers-reduced-motion: reduce)').matches
        ) {
            this._sizeSurfaceReady = true;
        }

        this._accountChangeSubscription = subscribe(
            this.messageContext,
            accountChangeChannel,
            (message) => {
                this._effectiveAccountId = message.accountId || null;
                this.getCampaignCategoryTree();
            },
            { scope: APPLICATION_SCOPE }
        );
        this.getCampaignCategoryTree();
        if (!this.loaded) {
            Promise.all([
                loadStyle(this, B2BFPsearchCardCSS)
            ])
                .then(() => {
                    this.loaded = true;
                    console.log('style loaded');
                })
                .catch(error => {
                    console.log(error.body.message);
                });
        }
    }

    disconnectedCallback() {
        if (this._accountChangeSubscription) {
            unsubscribe(this._accountChangeSubscription);
            this._accountChangeSubscription = null;
        }
    }

    renderedCallback() {
        if (!this.productAggregates) {
            return;
        }
        this.scheduleSizeSurfaceReveal();
    }

    scheduleSizeSurfaceReveal() {
        if (this._sizeSurfaceReady) {
            return;
        }
        if (
            typeof window !== 'undefined' &&
            window.matchMedia &&
            window.matchMedia('(prefers-reduced-motion: reduce)').matches
        ) {
            this._sizeSurfaceReady = true;
            return;
        }
        if (this._sizeRevealScheduled) {
            return;
        }
        this._sizeRevealScheduled = true;
        window.requestAnimationFrame(() => {
            this._sizeSurfaceReady = true;
            this._sizeRevealScheduled = false;
        });
    }

    get sizeSectionClass() {
        return this._sizeSurfaceReady
            ? 'sizesSection sizesSection--revealed'
            : 'sizesSection';
    }

     getCampaignCategoryTree() {
        const campaignPromise = getCampaignInfo({ campaignId: this.campaignId })
            .then((result) => {
                if (result) {
                    this.showInventory = result.OrderType != 'Prebook';
                }
                return result;
            })
            .catch((error) => {
                console.error(error);
                this.items = [];
                this._isLoading = false;
                this.showInventory = true;
                return null;
            });

        const sizesPromise = this.getSizeTemplateSizes();

        Promise.all([campaignPromise, sizesPromise]).then(([, sizeTemplateSizes]) => {
            this.getProductAggregates(sizeTemplateSizes);
        });
    }

    async getSizeTemplateSizes(){
        let productIds = [this.productId];
        try{
            let sizeTemplateSizes = await getSizeTemplateSizes({
                productIds,
            });
            return sizeTemplateSizes;
        }
        catch(error){
            //this.showToast('Error19', this.getErrorMessage(error), 'error');
            console.log(error);
        }
     }

    getProductAggregates(sizeTemplateSizes) {
        getProductAggregates({ productId: this.productId, campaignId: this.campaignId, effectiveAccountId: this._effectiveAccountId })
            .then((result) => {
                const rows = Array.isArray(result) ? result : [];
                const imageWithColorMap = this.buildImageWithColorMap();

                let productSizeTemplate = sizeTemplateSizes ? sizeTemplateSizes[this.productId] : [];
                this.sortedSizes = (productSizeTemplate.length > 0 ? sizeTemplateSizes[this.productId].map(({ XC_Size__c }) => XC_Size__c) : [' ']);

                const sortedResult = productSizeTemplate ? [...rows].sort((a, b) => {
                    if (a.color === b.color) {
                        return this.sortedSizes.indexOf(a.size) - this.sortedSizes.indexOf(b.size);
                    }
                    return a.color.localeCompare(b.color);
                }): rows;

                this.productAggregates = {};
                this.productAggregates.colName = 'Size';
                this.productAggregates.rowName = 'Color';
                let colValues = [];
                let rowValues = [];
                for (let i = 0; i < sortedResult.length; i++) {
                    let colValue = colValues.find(x => x.value == sortedResult[i].size);
                    if (!colValue) {
                        colValues.push({ value: sortedResult[i].size });
                    }
                    let formatDate = this.formatDate(sortedResult[i].availablityStart) + ' To ' + this.formatDate(sortedResult[i].availablityEnd);
                    let simpleProduct = this.productId == sortedResult[i].productId ? true : false;
                    let showQtyBox = simpleProduct ? true : sortedResult[i].color ? true : false;

                    for (let j = 0; j < this.sortedSizes.length; j++) {
                        let cSize = simpleProduct ? '' : this.sortedSizes[j];
                        let matchedSize = sortedResult[i].size == cSize ? true : false;
                        let qty = matchedSize ? (sortedResult[i].quantity ? sortedResult[i].quantity.toFixed(0) : 0) : 0;
                        let disabled = !qty && this.showInventory;
                        let imgColor = this.colorToPrimaryColorMap.get(sortedResult[i].color);
                        let imgSrc = '';



                        // Determine the image source based on the primary color
                        switch (imgColor) {
                            case 'Red': imgSrc = this.b2bRedSwatch; break;
                            case 'Pink': imgSrc = this.b2bPinkSwatch; break;
                            case 'Orange': imgSrc = this.b2bOrangeSwatch; break;
                            case 'Yellow': imgSrc = this.b2bYellowSwatch; break;
                            case 'Blue': imgSrc = this.b2bBlueSwatch; break;
                            case 'Green': imgSrc = this.b2bGreenSwatch; break;
                            case 'Purple': imgSrc = this.b2bPurpleSwatch; break;
                            case 'Brown': imgSrc = this.b2bBrownSwatch; break;
                            case 'Black': imgSrc = this.b2bBlackSwatch; break;
                            case 'Grey': imgSrc = this.b2bGreySwatch; break;
                            case 'White': imgSrc = this.b2bWhiteSwatch; break;
                            default: imgSrc = '';
                        }


                        if (sortedResult[i].color == 'Multi') {
                            imgSrc = this.b2bMultiImg;
                        }

                        const variantImgSrc = this.getImageForVariantColor(sortedResult[i].color, imageWithColorMap);

                        // For Prebook campaigns (showInventory=false): group by color only so one row
                        // covers all inventory windows, deduplicate cells by color+size, never disable.
                        let rowMatchDate = this.showInventory ? formatDate : null;
                        let rowArray = rowValues.find(x => (x.value == sortedResult[i].color && x.inventoryDate == rowMatchDate));
                        let rowArrayIndex = rowValues.findIndex(x => (x.value == sortedResult[i].color && x.inventoryDate == rowMatchDate));
                        let variantKey = sortedResult[i].productId + '-' + cSize + (this.showInventory ? '-' + formatDate : '');
                        let arrayKey = simpleProduct ? sortedResult[i].productId : variantKey;
                        let colorSizeDate = sortedResult[i].color + '-' + cSize + (this.showInventory ? '-' + formatDate : '');

                        if (rowArray) {
                            if (!rowArray.variantImgSrc && variantImgSrc) {
                                rowArray.variantImgSrc = variantImgSrc;
                                rowArray.headerCellClass = this.getRowHeaderCellClass(variantImgSrc);
                            }
                            let foundIndex = rowArray.keyMap.findIndex((x) => (x.colorSizeDate === colorSizeDate));
                            if(foundIndex >= 0) {
                                if(matchedSize) {
                                    rowArray.keyMap[foundIndex].prodId = sortedResult[i].productId;
                                    rowArray.keyMap[foundIndex].quantity = qty;
                                    rowArray.keyMap[foundIndex].maxQuantity = this.showInventory ? qty : null;
                                    rowArray.keyMap[foundIndex].disabled = disabled;
                                    rowArray.keyMap[foundIndex].key = variantKey;
                                    rowArray.keyMap[foundIndex].price = sortedResult[i].price ? sortedResult[i].price.toFixed(2) : undefined;
                                    rowArray.keyMap[foundIndex].sku = sortedResult[i].sku || '';
                                    rowArray.keyMap[foundIndex].size = cSize || sortedResult[i].size || '';
                                    rowArray.keyMap[foundIndex].rowIdx = rowArrayIndex;
                                    rowArray.keyMap[foundIndex].colIdx = foundIndex;
                                    rowArray.keyMap[foundIndex].inventoryItemId = sortedResult[i].inventoryItemId || null;
                                }
                            }else {
                                let cellIndex = rowArray.keyMap.length;
                                rowArray.keyMap.push({
                                    prodId: sortedResult[i].productId,
                                    key: simpleProduct ? sortedResult[i].productId : arrayKey,
                                    value: sortedResult[i].color,
                                    cellQty: "0",
                                    price: sortedResult[i].price ? sortedResult[i].price.toFixed(2) : undefined,
                                    sku: sortedResult[i].sku || '',
                                    size: cSize || sortedResult[i].size || '',
                                    quantity: qty,
                                    maxQuantity: this.showInventory ? qty : null,
                                    disabled: disabled,
                                    rowIdx: rowArrayIndex,
                                    colIdx: cellIndex,
                                    Startfrom: formatDate,
                                    showQtyBox: showQtyBox,
                                    colorSizeDate: colorSizeDate,
                                    inventoryItemId: sortedResult[i].inventoryItemId || null
                                });
                            }
                        } else {
                            rowValues.push({
                                inventoryDate: this.showInventory ? formatDate : null,
                                value: sortedResult[i].color,
                                key: simpleProduct ? this.productId : sortedResult[i].color,
                                imgSrc: imgSrc,
                                variantImgSrc: variantImgSrc,
                                headerCellClass: this.getRowHeaderCellClass(variantImgSrc),
                                keyMap: [{
                                    prodId: sortedResult[i].productId,
                                    key: simpleProduct ? sortedResult[i].productId : arrayKey,
                                    value: sortedResult[i].color,
                                    cellQty: "0",
                                    price: sortedResult[i].price ? sortedResult[i].price.toFixed(2) : undefined,
                                    sku: sortedResult[i].sku || '',
                                    size: cSize || sortedResult[i].size || '',
                                    quantity: qty,
                                    maxQuantity: this.showInventory ? qty : null,
                                    disabled: disabled,
                                    rowIdx: rowValues.length,
                                    colIdx: 0,
                                    Startfrom: formatDate,
                                    showQtyBox: showQtyBox,
                                    colorSizeDate: colorSizeDate,
                                    inventoryItemId: sortedResult[i].inventoryItemId || null
                                }]
                            });
                        }
                    }
                }

                this.productAggregates.colValues = colValues;
                this.productAggregates.rowValues = rowValues;
            })
            .catch((error) => {
                console.log(error);
                this.productAggregates = {
                    colName: 'Size',
                    rowName: 'Color',
                    colValues: [],
                    rowValues: []
                };
            });
    }

    get hasRecommendation() {
        return this.recommendation && Array.isArray(this.recommendation.lines) && this.recommendation.lines.length > 0;
    }

    get recommendationWarnings() {
        return this.recommendation && Array.isArray(this.recommendation.warnings)
            ? this.recommendation.warnings
            : [];
    }

    get hasRecommendationWarnings() {
        return this.recommendationWarnings.length > 0;
    }

    get recommendationCurrencyCode() {
        return this.recommendation?.currencyIsoCode || currency;
    }

    get recommendationTemplateOptions() {
        return [
            { label: 'Auto', value: 'AUTO' },
            { label: 'Balanced Core', value: 'BALANCED_CORE' },
            { label: 'Equal Coverage', value: 'EQUAL_COVERAGE' },
            { label: 'Core Heavy', value: 'CORE_HEAVY' },
            { label: 'Medium/Large Skew', value: 'MEDIUM_LARGE_SKEW' },
            { label: 'Conservative Launch', value: 'CONSERVATIVE_LAUNCH' }
        ];
    }

    get allSavedSizeRunOptions() {
        const optionsByValue = new Map();
        for (const option of this.sizeRunOptions || []) {
            if (option?.value) {
                optionsByValue.set(this.getSavedSizeRunOptionKey(option), option);
            }
        }
        for (const option of this.localSavedSizeRunOptions || []) {
            if (option?.value) {
                optionsByValue.set(this.getSavedSizeRunOptionKey(option), option);
            }
        }
        return Array.from(optionsByValue.values());
    }

    getSavedSizeRunOptionKey(option) {
        if (option?.recordId) {
            return `record:${option.recordId}`;
        }
        if (!option?.value) {
            return option?.label || '';
        }
        try {
            const parsed = JSON.parse(option.value);
            return JSON.stringify(this.canonicalizeSavedSizeRunValue(parsed));
        } catch (error) {
            return option.value;
        }
    }

    canonicalizeSavedSizeRunValue(value) {
        if (Array.isArray(value)) {
            return value
                .map((entry) => ({
                    size: entry?.size || '',
                    quantity: Number(entry?.quantity) || 0
                }))
                .sort((left, right) => left.size.localeCompare(right.size));
        }
        if (value?.templateType === 'PRODUCT_GRID' && Array.isArray(value.lines)) {
            return {
                templateType: 'PRODUCT_GRID',
                productId: value.productId || '',
                lines: value.lines
                    .map((line) => ({
                        productId: line?.productId || '',
                        sku: line?.sku || '',
                        size: line?.size || '',
                        quantity: Number(line?.quantity) || 0
                    }))
                    .sort((left, right) => {
                        const skuCompare = left.sku.localeCompare(right.sku);
                        return skuCompare !== 0 ? skuCompare : left.size.localeCompare(right.size);
                    })
            };
        }
        return value;
    }

    get hasSavedRecommendationOptions() {
        return this.allSavedSizeRunOptions.length > 0;
    }

    get savedSizeRunSelectOptions() {
        return this.allSavedSizeRunOptions.map((option) => ({
            ...option,
            selectValue: this.getSavedSizeRunSelectValue(option)
        }));
    }

    getSavedSizeRunSelectValue(option) {
        return option?.recordId ? `record:${option.recordId}` : `value:${option?.value || ''}`;
    }

    get selectedSavedRecommendationOption() {
        if (!this.selectedSavedSizeRunKey && !this.selectedSavedSizeRunValue) {
            return null;
        }
        return this.allSavedSizeRunOptions.find((option) => (
            this.getSavedSizeRunSelectValue(option) === this.selectedSavedSizeRunKey ||
            option.value === this.selectedSavedSizeRunValue
        )) || null;
    }

    get selectedSavedRecommendationRecordId() {
        return this.selectedSavedRecommendationOption?.recordId || null;
    }

    get hasSelectedSavedRecommendation() {
        return !!this.selectedSavedRecommendationRecordId;
    }

    get disableDeleteSavedRecommendation() {
        return this.isDeletingRecommendation || !this.hasSelectedSavedRecommendation;
    }

    get deleteSavedRecommendationButtonLabel() {
        return this.isDeletingRecommendation ? 'Deleting...' : 'Delete';
    }

    get recommendationTemplateLabel() {
        return this.recommendation?.sizeCurveTemplateLabel || '';
    }

    get recommendButtonLabel() {
        return this.isRecommending ? 'Calculating...' : 'Calculate';
    }

    get disableRecommendButton() {
        return this.isRecommending || !this.productAggregates;
    }

    get disableApplyRecommendation() {
        return !this.hasRecommendation;
    }

    get recommendationStatusLabel() {
        if (!this.recommendation?.status) {
            return '';
        }
        const labelsByStatus = {
            READY: 'Order History Based',
            NO_HISTORY_FALLBACK_USED: 'Balanced Fallback',
            INSUFFICIENT_BUDGET: 'Minimum Run',
            MISSING_INPUT: 'Needs Input',
            INVALID_STYLE: 'Style Not Found',
            NO_CHILD_SKUS: 'No Sizes Found',
            PRICING_UNAVAILABLE: 'Pricing Unavailable',
            ERROR: 'Unable to Calculate'
        };
        if (labelsByStatus[this.recommendation.status]) {
            return labelsByStatus[this.recommendation.status];
        }
        return this.recommendation.status
            .toLowerCase()
            .split('_')
            .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
            .join(' ');
    }

    get maxAgentPromptLength() {
        return 240;
    }

    get agentToggleIconName() {
        return this.isAgentPanelExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get agentRemainingCharacters() {
        return this.maxAgentPromptLength - (this.agentPrompt || '').length;
    }

    get disableAgentSend() {
        return this.isAgentSending || !this.agentPrompt || !this.agentPrompt.trim() || !this.hasRecommendation;
    }

    get agentSendButtonLabel() {
        return this.isAgentSending ? 'Sending...' : 'Send';
    }

    get hasAgentPreview() {
        return this.agentPreview?.recommendation?.lines?.length > 0;
    }

    get agentPreviewDiffs() {
        return Array.isArray(this.agentPreview?.diffs) ? this.agentPreview.diffs : [];
    }

    get hasAgentPreviewDiffs() {
        return this.agentPreviewDiffs.length > 0;
    }

    get agentPreviewTotalUnits() {
        return this.agentPreview?.recommendation?.totalRecommendedQuantity || 0;
    }

    get agentPreviewEstimatedAmount() {
        return this.agentPreview?.recommendation?.estimatedRecommendationAmount || 0;
    }

    get disableSaveRecommendation() {
        return this.isSavingRecommendation || !this.savedRecommendationName || !this.savedRecommendationName.trim() || !this.hasRecommendation;
    }

    get saveRecommendationButtonLabel() {
        if (this.isSavingRecommendation) {
            return 'Saving...';
        }
        return this.hasSelectedSavedRecommendation ? 'Save Changes' : 'Save Recommendation';
    }

    get saveRecommendationTemplateTypeLabel() {
        return this.isCurrentRecommendationProductGridTemplate ? 'Product Grid Template' : 'Size Curve Template';
    }

    get saveRecommendationTemplateTypeHelp() {
        return this.isCurrentRecommendationProductGridTemplate
            ? 'This keeps the exact SKU/color/size quantities from the preview.'
            : 'This saves one reusable quantity per size.';
    }

    get isAgentPreviewProductGridTemplate() {
        return this.recommendationHasVariantSpecificQuantities(this.agentPreview?.recommendation);
    }

    get isCurrentRecommendationProductGridTemplate() {
        return this.recommendationHasVariantSpecificQuantities(this.recommendation);
    }

    handleRecommendationAmountChange(event) {
        this.recommendationAmount = event.target.value;
        this.recommendationError = null;
    }

    handleRecommendationTemplateChange(event) {
        this.selectedRecommendationTemplate = event.target.value;
        this.recommendationError = null;
        this.selectedSavedSizeRunValue = '';
        this.selectedSavedSizeRunKey = '';
        this.resetAgentPreview();
        if (this.hasRecommendation) {
            this.requestRecommendation();
        }
    }

    handleSavedSizeRunChange(event) {
        this.selectedSavedSizeRunKey = event.target.value;
        this.recommendationError = null;
        this.saveRecommendationError = '';
        this.saveRecommendationMessage = '';
        if (!this.selectedSavedSizeRunKey) {
            this.selectedSavedSizeRunValue = '';
            this.syncSavedRecommendationSelect();
            return;
        }
        const selectedOption = this.selectedSavedRecommendationOption;
        this.selectedSavedSizeRunValue = selectedOption?.value || '';
        this.loadSavedRecommendationToRecommendationGrid();
    }

    loadSavedRecommendationToRecommendationGrid() {
        const option = this.selectedSavedRecommendationOption;
        if (!option?.value) {
            this.recommendationError = 'Select a saved recommendation first.';
            return;
        }
        const recommendation = this.buildRecommendationFromSavedSizeRunOption(option);
        if (!recommendation?.lines?.length) {
            this.recommendation = null;
            this.recommendationError = 'This saved recommendation does not match any enabled grid rows for this product.';
            return;
        }

        this.recommendation = this.decorateRecommendation(recommendation);
        this.savedRecommendationName = option.name || this.savedRecommendationLabelToName(option.label);
        this.saveAvailableToAllUsers = option.availableToAllUsers === true;
        this.resetAgentPreview();
        this.saveRecommendationError = '';
        this.saveRecommendationMessage = '';
    }

    savedRecommendationLabelToName(label) {
        return (label || '').replace(/\s+\(Product Grid\)$/i, '');
    }

    @api
    openRecommendationDialog() {
        this.showRecommendationDialog = true;
    }

    closeRecommendationDialog() {
        this.showRecommendationDialog = false;
    }

    toggleAgentPanel() {
        const shouldExpand = !this.isAgentPanelExpanded;
        this.isAgentPanelExpanded = shouldExpand;

        if (shouldExpand) {
            this.focusAgentPanel();
        }
    }

    handleAgentPromptInput(event) {
        this.agentPrompt = event.target.value;
        this.agentError = '';
    }

    handleSavedRecommendationNameChange(event) {
        this.savedRecommendationName = event.target.value;
        this.saveRecommendationError = '';
        this.saveRecommendationMessage = '';
    }

    handleSaveAvailableToAllUsersChange(event) {
        this.saveAvailableToAllUsers = event.target.checked;
        this.saveRecommendationError = '';
        this.saveRecommendationMessage = '';
    }

    sendAgentPrompt() {
        const prompt = (this.agentPrompt || '').trim();
        if (!prompt) {
            this.agentError = 'Enter a question or adjustment.';
            return;
        }
        if (prompt.length > this.maxAgentPromptLength) {
            this.agentError = `Keep the request under ${this.maxAgentPromptLength} characters.`;
            return;
        }
        if (!this.hasRecommendation) {
            this.agentError = 'Calculate a recommendation first.';
            return;
        }

        this.isAgentSending = true;
        this.agentError = '';
        this.agentPreview = null;
        this.clearSaveRecommendationFeedback();
        this.addAgentMessage('You', prompt, 'agentMessage agentMessage--user');

        const requestPayload = {
            productId: this.productId,
            totalOrderAmount: this.numericRecommendationAmount,
            effectiveAccountId: this.resolvedEffectiveAccountId,
            webStoreId: null,
            campaignId: this.campaignId,
            currencyIsoCode: this.recommendationCurrencyCode,
            selectedTemplate: this.selectedRecommendationTemplate || this.recommendation?.sizeCurveTemplate || 'AUTO',
            userPrompt: prompt,
            currentRecommendation: this.serializableRecommendation
        };
        this.agentPrompt = '';
        this.clearAgentPromptInput();

        adjustRecommendation({
            requestJson: JSON.stringify(requestPayload)
        })
            .then((result) => {
                const response = this.decorateAgentResponse(result);
                this.addAgentMessage(
                    'Assistant',
                    response?.message || 'I could not build a response.',
                    'agentMessage agentMessage--assistant'
                );
                if (response?.revised && response?.recommendation?.lines?.length > 0) {
                    this.agentPreview = response;
                }
            })
            .catch((error) => {
                this.agentError = this.getErrorMessage(error);
            })
            .finally(() => {
                this.isAgentSending = false;
            });
    }

    saveAgentRecommendation() {
        if (!this.hasRecommendation) {
            this.saveRecommendationError = 'Load, calculate, or adjust a recommendation before saving it.';
            return;
        }
        const recommendationName = (this.savedRecommendationName || '').trim();
        if (!recommendationName) {
            this.saveRecommendationError = 'Enter a name for the saved recommendation.';
            return;
        }

        this.isSavingRecommendation = true;
        this.saveRecommendationError = '';
        this.saveRecommendationMessage = '';

        const selectedRecordId = this.selectedSavedRecommendationRecordId;
        const requestPayload = {
            recordId: selectedRecordId,
            productId: this.productId,
            recommendationName,
            availableToAllUsers: this.saveAvailableToAllUsers,
            recommendation: this.serializableRecommendation
        };

        saveRecommendation({
            requestJson: JSON.stringify(requestPayload)
        })
            .then((result) => {
                if (result?.status === 'READY') {
                    this.saveRecommendationMessage = result.message || 'Recommendation saved.';
                    this.addLocalSavedRecommendationOption(result, recommendationName, !!selectedRecordId);
                    this.savedRecommendationName = result.name || recommendationName;
                    this.saveAvailableToAllUsers = result.availableToAllUsers === true;
                    this.dispatchEvent(new CustomEvent('sizerunsaved', {
                        bubbles: true,
                        composed: true,
                        detail: {
                            recordId: result.recordId,
                            name: result.name,
                            availableToAllUsers: result.availableToAllUsers,
                            templateType: result.templateType,
                            option: this.localSavedSizeRunOptions[this.localSavedSizeRunOptions.length - 1]
                        }
                    }));
                } else {
                    this.saveRecommendationError = result?.message || 'I could not save that recommendation.';
                }
            })
            .catch((error) => {
                this.saveRecommendationError = this.getErrorMessage(error);
            })
            .finally(() => {
                this.isSavingRecommendation = false;
            });
    }

    deleteSavedRecommendation() {
        const option = this.selectedSavedRecommendationOption;
        if (!option?.recordId) {
            this.saveRecommendationError = 'Select a saved recommendation to delete.';
            return;
        }

        this.isDeletingRecommendation = true;
        this.saveRecommendationError = '';
        this.saveRecommendationMessage = '';

        deleteRecommendation({
            recordId: option.recordId
        })
            .then((result) => {
                if (result?.status === 'READY') {
                    this.removeLocalSavedRecommendationOption(option);
                    this.dispatchEvent(new CustomEvent('sizerundeleted', {
                        bubbles: true,
                        composed: true,
                        detail: {
                            recordId: option.recordId,
                            value: option.value
                        }
                    }));
                    this.selectedSavedSizeRunValue = '';
                    this.selectedSavedSizeRunKey = '';
                    this.recommendation = null;
                    this.resetSaveRecommendationState();
                    this.saveRecommendationMessage = result.message || 'Saved recommendation deleted.';
                    toast.show({
                        label: 'Saved recommendation deleted',
                        message: result.message || 'The saved recommendation was deleted.',
                        variant: 'success',
                        mode: 'dismissable'
                    }, this);
                } else {
                    this.saveRecommendationError = result?.message || 'I could not delete that recommendation.';
                }
            })
            .catch((error) => {
                this.saveRecommendationError = this.getErrorMessage(error);
            })
            .finally(() => {
                this.isDeletingRecommendation = false;
            });
    }

    addLocalSavedRecommendationOption(result, fallbackName, shouldSelect = true) {
        const name = result?.name || fallbackName;
        const templateType = result?.templateType || (this.isCurrentRecommendationProductGridTemplate ? 'PRODUCT_GRID' : 'SIZE_CURVE');
        const value = this.buildSavedSizeRunValue(this.recommendation, templateType);
        if (!name || !value) {
            return;
        }
        const label = templateType === 'PRODUCT_GRID' ? `${name} (Product Grid)` : name;
        const option = {
            label,
            value,
            recordId: result?.recordId || this.selectedSavedRecommendationRecordId,
            name,
            templateType,
            availableToAllUsers: result?.availableToAllUsers === true
        };
        this.localSavedSizeRunOptions = [
            ...this.localSavedSizeRunOptions.filter((existing) => {
                if (option.recordId && existing.recordId === option.recordId) {
                    return false;
                }
                return this.getSavedSizeRunOptionKey(existing) !== this.getSavedSizeRunOptionKey(option);
            }),
            option
        ];
        this.selectedSavedSizeRunValue = shouldSelect ? value : '';
        this.selectedSavedSizeRunKey = shouldSelect ? this.getSavedSizeRunSelectValue(option) : '';
        this.syncSavedRecommendationSelect();
    }

    removeLocalSavedRecommendationOption(optionToRemove) {
        this.localSavedSizeRunOptions = this.localSavedSizeRunOptions.filter((option) => {
            if (optionToRemove.recordId && option.recordId === optionToRemove.recordId) {
                return false;
            }
            return option.value !== optionToRemove.value;
        });
    }

    buildSavedSizeRunValue(recommendation, templateType) {
        if (!recommendation?.lines?.length) {
            return '';
        }
        if (templateType === 'PRODUCT_GRID') {
            return JSON.stringify({
                templateType: 'PRODUCT_GRID',
                productId: this.productId,
                lines: recommendation.lines.map((line) => ({
                    productId: line.productId,
                    sku: line.sku,
                    size: line.size,
                    quantity: Number(line.quantity) || 0
                }))
            });
        }

        const quantityBySize = new Map();
        for (const line of recommendation.lines) {
            if (line.size && !quantityBySize.has(line.size)) {
                quantityBySize.set(line.size, Number(line.quantity) || 0);
            }
        }
        return JSON.stringify(Array.from(quantityBySize.entries()).map(([size, quantity]) => ({
            size,
            quantity
        })));
    }

    clearAgentPromptInput() {
        const promptInput = this.template.querySelector('.promptInput');
        if (promptInput) {
            promptInput.value = '';
        }
    }

    focusAgentPanel() {
        window.setTimeout(() => {
            const agentBody = this.template.querySelector('.agentBody');
            const promptInput = this.template.querySelector('.promptInput');

            if (agentBody) {
                agentBody.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start',
                    inline: 'nearest'
                });
            }

            if (promptInput) {
                promptInput.focus();
            }
        }, 0);
    }

    applyAgentPreview() {
        if (!this.hasAgentPreview) {
            return;
        }
        this.recommendation = this.agentPreview.recommendation;
        this.agentPreview = null;
        this.saveRecommendationError = '';
        this.saveRecommendationMessage = 'Changes are staged in the Recommendation Matrix. Use Apply to Grid when you are ready.';
    }

    addAgentMessage(label, text, className) {
        this._agentMessageIndex += 1;
        this.agentMessages = [
            ...this.agentMessages,
            {
                key: `${label}-${this._agentMessageIndex}`,
                label,
                text,
                className
            }
        ];
    }

    resetAgentPreview() {
        this.agentPreview = null;
        this.agentError = '';
        this.clearSaveRecommendationFeedback();
    }

    resetSaveRecommendationState() {
        this.savedRecommendationName = '';
        this.saveAvailableToAllUsers = false;
        this.isSavingRecommendation = false;
        this.isDeletingRecommendation = false;
        this.clearSaveRecommendationFeedback();
    }

    clearSaveRecommendationFeedback() {
        this.saveRecommendationError = '';
        this.saveRecommendationMessage = '';
    }

    syncSavedRecommendationSelect() {
        window.setTimeout(() => {
            const savedSelect = this.template.querySelector('#saved-recommendation-template');
            if (savedSelect) {
                savedSelect.value = this.selectedSavedSizeRunKey || '';
            }
        }, 0);
    }

    get numericRecommendationAmount() {
        const amount = Number(this.recommendationAmount);
        if (Number.isFinite(amount) && amount > 0) {
            return amount;
        }
        return this.recommendation?.totalOrderAmount || null;
    }

    get serializableRecommendation() {
        if (!this.recommendation) {
            return null;
        }
        const lines = Array.isArray(this.recommendation.lines)
            ? this.recommendation.lines.map((line) => ({
                productId: line.productId,
                sku: line.sku,
                size: line.size,
                quantity: Number(line.quantity) || 0,
                unitPrice: Number(line.unitPrice) || 0,
                estimatedAmount: Number(line.estimatedAmount) || 0
            }))
            : [];
        return {
            status: this.recommendation.status,
            message: this.recommendation.message,
            styleId: this.recommendation.styleId,
            styleName: this.recommendation.styleName,
            totalOrderAmount: Number(this.recommendation.totalOrderAmount) || this.numericRecommendationAmount,
            minimumRecommendedAmount: Number(this.recommendation.minimumRecommendedAmount) || 0,
            estimatedRecommendationAmount: Number(this.recommendation.estimatedRecommendationAmount) || 0,
            totalRecommendedQuantity: Number(this.recommendation.totalRecommendedQuantity) || 0,
            currencyIsoCode: this.recommendationCurrencyCode,
            sizeCurveTemplate: this.recommendation.sizeCurveTemplate,
            sizeCurveTemplateLabel: this.recommendation.sizeCurveTemplateLabel,
            warnings: Array.isArray(this.recommendation.warnings) ? [...this.recommendation.warnings] : [],
            lines
        };
    }

    decorateAgentResponse(result) {
        if (!result) {
            return null;
        }
        const recommendation = result.recommendation
            ? this.decorateRecommendation(result.recommendation)
            : null;
        return {
            ...result,
            recommendation,
            diffs: this.decorateAdjustmentDiffs(result.diffs, recommendation)
        };
    }

    requestRecommendation() {
        const amount = Number(this.recommendationAmount);
        if (!Number.isFinite(amount) || amount <= 0) {
            this.recommendationError = 'Enter an order amount before requesting a recommendation.';
            this.recommendation = null;
            return;
        }

        this.isRecommending = true;
        this.recommendationError = null;
        this.selectedSavedSizeRunValue = '';
        this.selectedSavedSizeRunKey = '';
        this.resetSaveRecommendationState();
        recommendSizeRun({
            productId: this.productId,
            totalOrderAmount: amount,
            effectiveAccountId: this.resolvedEffectiveAccountId,
            webStoreId: null,
            campaignId: this.campaignId,
            currencyIsoCode: currency,
            sizeCurveTemplate: this.selectedRecommendationTemplate || 'AUTO'
        })
            .then((result) => {
                this.recommendation = this.decorateRecommendation(result);
                this.resetAgentPreview();
                if (!this.hasRecommendation) {
                    this.recommendationError = result?.message || 'No recommendation lines were returned.';
                }
            })
            .catch((error) => {
                this.recommendation = null;
                this.recommendationError = this.getErrorMessage(error);
            })
            .finally(() => {
                this.isRecommending = false;
            });
    }

    decorateRecommendation(result) {
        if (!result) {
            return null;
        }
        const normalized = this.normalizeRecommendationForGrid(result);
        const lines = Array.isArray(normalized.lines)
            ? normalized.lines.map((line, index) => ({
                ...line,
                rowNumber: index + 1,
                key: `${line.productId || line.sku || line.size || index}-${index}`
            }))
            : [];
        return {
            ...normalized,
            lines
        };
    }

    decorateAdjustmentDiffs(diffs, recommendation) {
        if (!Array.isArray(diffs) || !recommendation?.lines?.length) {
            return [];
        }
        const lineByKey = new Map();
        for (const line of recommendation.lines) {
            this.recommendationLineKeys(line).forEach((key) => lineByKey.set(key, line));
        }

        return diffs
            .map((diff, index) => {
                const key = diff.key || this.stableRecommendationLineKey(diff);
                const line = key ? lineByKey.get(key) : null;
                if (!line) {
                    return null;
                }
                return {
                    ...diff,
                    key: key || `${diff.sku || diff.size || index}-${index}`,
                    sku: line.sku || diff.sku,
                    size: line.size || diff.size,
                    rowNumber: line.rowNumber,
                    rowLabel: `#${line.rowNumber} ${line.sku || line.size || 'Line'}${line.size ? ` (${line.size})` : ''}`
                };
            })
            .filter((diff) => diff);
    }

    normalizeRecommendationForGrid(result) {
        if (!result || !Array.isArray(result.lines)) {
            return result;
        }

        const indexes = this.buildEnabledGridCellIndexes();
        if (!indexes.hasCells) {
            return {
                ...result,
                lines: [...result.lines]
            };
        }

        let skippedCount = 0;
        let cappedCount = 0;
        const lines = [];
        for (const sourceLine of result.lines) {
            const cell = this.findCellForRecommendationLine(sourceLine, indexes);
            if (!cell) {
                skippedCount += 1;
                continue;
            }

            const requestedQty = Number(sourceLine.quantity) || 0;
            let quantity = Math.max(0, requestedQty);
            if (this.showInventory && cell.maxQuantity !== null && cell.maxQuantity !== undefined) {
                const maxQty = Number(cell.maxQuantity) || 0;
                if (quantity > maxQty) {
                    quantity = maxQty;
                    cappedCount += 1;
                }
            }
            const unitPrice = Number(sourceLine.unitPrice ?? cell.price) || 0;
            lines.push({
                ...sourceLine,
                productId: sourceLine.productId || cell.prodId,
                sku: sourceLine.sku || cell.sku,
                size: sourceLine.size || cell.size,
                quantity,
                unitPrice,
                estimatedAmount: quantity * unitPrice
            });
        }

        const totalRecommendedQuantity = lines.reduce((sum, line) => sum + (Number(line.quantity) || 0), 0);
        const estimatedRecommendationAmount = lines.reduce((sum, line) => sum + (Number(line.estimatedAmount) || 0), 0);
        const warnings = Array.isArray(result.warnings) ? [...result.warnings] : [];
        if (skippedCount > 0) {
            warnings.push(`${skippedCount} SKU(s) were not included because they are not enabled in the current grid.`);
        }
        if (cappedCount > 0) {
            warnings.push(`${cappedCount} line(s) were capped by available inventory before preview.`);
        }

        return {
            ...result,
            warnings,
            lines,
            totalRecommendedQuantity,
            estimatedRecommendationAmount
        };
    }

    buildEnabledGridCellIndexes() {
        const indexes = {
            productIdMap: new Map(),
            skuMap: new Map(),
            sizeMap: new Map(),
            hasCells: false
        };
        if (!this.productAggregates?.rowValues) {
            return indexes;
        }

        for (const row of this.productAggregates.rowValues) {
            for (const cell of row.keyMap || []) {
                const isUsableCell = cell && !cell.disabled && cell.showQtyBox;
                if (!isUsableCell) {
                    continue;
                }
                indexes.hasCells = true;
                if (cell.prodId && !indexes.productIdMap.has(cell.prodId)) {
                    indexes.productIdMap.set(cell.prodId, cell);
                }
                if (cell.sku && !indexes.skuMap.has(String(cell.sku).toLowerCase())) {
                    indexes.skuMap.set(String(cell.sku).toLowerCase(), cell);
                }
                if (cell.size && !indexes.sizeMap.has(String(cell.size).toLowerCase())) {
                    indexes.sizeMap.set(String(cell.size).toLowerCase(), cell);
                }
            }
        }
        return indexes;
    }

    findCellForRecommendationLine(line, indexes) {
        if (!line || !indexes) {
            return null;
        }
        if (line.productId && indexes.productIdMap.has(line.productId)) {
            return indexes.productIdMap.get(line.productId);
        }
        if (line.sku && indexes.skuMap.has(String(line.sku).toLowerCase())) {
            return indexes.skuMap.get(String(line.sku).toLowerCase());
        }
        if (!line.productId && !line.sku && line.size && indexes.sizeMap.has(String(line.size).toLowerCase())) {
            return indexes.sizeMap.get(String(line.size).toLowerCase());
        }
        return null;
    }

    buildRecommendationFromSavedSizeRunOption(option) {
        let parsed;
        try {
            parsed = JSON.parse(option.value);
        } catch (error) {
            return null;
        }

        const savedName = option.name || this.savedRecommendationLabelToName(option.label);
        const isProductGrid = parsed?.templateType === 'PRODUCT_GRID' && Array.isArray(parsed.lines);
        const lines = isProductGrid
            ? parsed.lines.map((line) => ({
                productId: line.productId,
                sku: line.sku,
                size: line.size,
                quantity: Number(line.quantity) || 0
            }))
            : this.buildSizeCurveLinesFromSavedTemplate(parsed);

        const templateLabel = isProductGrid ? 'Product Grid Template' : 'Saved Size Curve';
        return {
            status: 'READY',
            message: `Loaded saved recommendation "${savedName}". Review it in the Recommendation Matrix before applying it to the grid.`,
            styleId: this.productId,
            styleName: this.displayableProduct?.fields?.Name || this.displayableProduct?.name || '',
            totalOrderAmount: this.numericRecommendationAmount,
            minimumRecommendedAmount: 0,
            estimatedRecommendationAmount: 0,
            totalRecommendedQuantity: 0,
            currencyIsoCode: this.recommendationCurrencyCode,
            sizeCurveTemplate: isProductGrid ? 'PRODUCT_GRID' : 'SAVED_SIZE_CURVE',
            sizeCurveTemplateLabel: templateLabel,
            warnings: [],
            lines
        };
    }

    buildSizeCurveLinesFromSavedTemplate(savedSizes) {
        if (!Array.isArray(savedSizes) || !this.productAggregates?.rowValues) {
            return [];
        }

        const quantityBySize = new Map();
        for (const entry of savedSizes) {
            const sizeKey = String(entry?.size || '').trim().toLowerCase();
            if (sizeKey) {
                quantityBySize.set(sizeKey, Number(entry.quantity) || 0);
            }
        }

        const lines = [];
        for (const row of this.productAggregates.rowValues) {
            for (const cell of row.keyMap || []) {
                if (!cell || cell.disabled || !cell.showQtyBox) {
                    continue;
                }
                const sizeKey = String(cell.size || '').trim().toLowerCase();
                if (!quantityBySize.has(sizeKey)) {
                    continue;
                }
                lines.push({
                    productId: cell.prodId,
                    sku: cell.sku,
                    size: cell.size,
                    quantity: quantityBySize.get(sizeKey),
                    unitPrice: Number(cell.price) || 0
                });
            }
        }
        return lines;
    }

    stableRecommendationLineKey(line) {
        if (!line) {
            return '';
        }
        if (line.productId) {
            return line.productId;
        }
        if (line.sku) {
            return line.sku;
        }
        return line.size || '';
    }

    recommendationLineKeys(line) {
        if (!line) {
            return [];
        }
        return [line.productId, line.sku, line.size]
            .filter((key) => key !== null && key !== undefined && String(key).trim() !== '')
            .map((key) => String(key).trim());
    }

    recommendationHasVariantSpecificQuantities(recommendation) {
        const quantityBySize = new Map();
        for (const line of recommendation?.lines || []) {
            const sizeKey = (line.size || '').trim().toLowerCase();
            if (!sizeKey) {
                continue;
            }
            const quantity = Number(line.quantity) || 0;
            if (quantityBySize.has(sizeKey) && quantityBySize.get(sizeKey) !== quantity) {
                return true;
            }
            quantityBySize.set(sizeKey, quantity);
        }
        return false;
    }

    applyRecommendationToGrid(event) {
        const sourceRecommendation = event?.detail?.recommendation || this.recommendation;
        if (!sourceRecommendation?.lines?.length || !this.productAggregates?.rowValues) {
            return;
        }

        const unmatchedLines = [];
        const cappedLines = [];
        const indexes = this.buildEnabledGridCellIndexes();

        for (const line of sourceRecommendation.lines) {
            const cell = this.findCellForRecommendationLine(line, indexes);

            if (!cell || cell.disabled || !cell.showQtyBox) {
                unmatchedLines.push(line.sku || line.size || line.productId);
                continue;
            }

            const requestedQty = Number(line.quantity) || 0;
            let nextQty = requestedQty;
            if (this.showInventory && cell.maxQuantity !== null && cell.maxQuantity !== undefined) {
                const maxQty = Number(cell.maxQuantity) || 0;
                if (nextQty > maxQty) {
                    nextQty = maxQty;
                    cappedLines.push(line.sku || line.size || line.productId);
                }
            }
            cell.cellQty = String(Math.max(0, nextQty));
        }

        this.productAggregates = {
            ...this.productAggregates,
            rowValues: [...this.productAggregates.rowValues]
        };

        if (unmatchedLines.length > 0 || cappedLines.length > 0) {
            const details = [];
            if (unmatchedLines.length > 0) {
                details.push(`${unmatchedLines.length} line(s) could not be matched to enabled grid cells.`);
            }
            if (cappedLines.length > 0) {
                details.push(`${cappedLines.length} line(s) were capped by available inventory.`);
            }
            toast.show({
                label: 'Recommendation applied with warnings',
                message: details.join(' '),
                variant: 'warning',
                mode: 'dismissable'
            }, this);
        } else {
            toast.show({
                label: 'Recommendation applied',
                message: 'Recommended quantities were applied to the grid.',
                variant: 'success',
                mode: 'dismissable'
            }, this);
        }
        this.selectedSavedSizeRunValue = '';
        this.selectedSavedSizeRunKey = '';
        this.resetSaveRecommendationState();
        this.showRecommendationDialog = false;
    }

    normalizeColor(value) {
        return (value || '').toString().trim().toLowerCase();
    }

    getRowHeaderCellClass(variantImgSrc) {
        return variantImgSrc ? 'rowHeaderCell' : 'rowHeaderCell rowHeaderCell--no-image';
    }

    buildImageWithColorMap() {
        const imageMap = new Map();
        const alternateImages = this.displayableProduct?.alternateImages;
        if (!alternateImages || typeof alternateImages !== 'object') {
            return imageMap;
        }

        const debugSkippedItems = [];
        Object.values(alternateImages).forEach((groupItems) => {
            if (!Array.isArray(groupItems)) {
                return;
            }
            groupItems.forEach((mediaItem) => {
                const itemColor = this.extractImageColor(mediaItem);
                const normalizedColor = this.normalizeColor(itemColor);
                const imageUrl = extractImageUrl(mediaItem);
                if (!normalizedColor || !imageUrl || imageMap.has(normalizedColor)) {
                    if (debugSkippedItems.length < 6) {
                        debugSkippedItems.push({
                            normalizedColor,
                            hasImageUrl: !!imageUrl,
                            topLevelKeys: mediaItem && typeof mediaItem === 'object' ? Object.keys(mediaItem) : []
                        });
                    }
                    return;
                }
                imageMap.set(normalizedColor, imageUrl);
            });
        });

        console.log('[xcProductDetailsSizeDisplay] imageWithColorMap built', {
            size: imageMap.size,
            keys: Array.from(imageMap.keys()),
            skippedSample: imageMap.size === 0 ? debugSkippedItems : []
        });

        return imageMap;
    }

    extractImageColor(mediaItem) {
        if (!mediaItem || typeof mediaItem !== 'object') {
            return '';
        }

        const candidates = [
            mediaItem.Color,
            mediaItem.color,
            mediaItem?.fields?.Color?.value,
            mediaItem?.fields?.color?.value,
            mediaItem?.fields?.Color,
            mediaItem?.fields?.color,
            mediaItem?.contentNodes?.Color?.value,
            mediaItem?.contentNodes?.color?.value,
            mediaItem?.contentNodes?.Color?.text,
            mediaItem?.contentNodes?.color?.text
        ];
        const foundColor = candidates
            .map((item) => this.coerceToString(item))
            .find((item) => item !== '');
        if (foundColor) {
            return foundColor;
        }

        const nestedColor = this.findNestedStringByKey(mediaItem, 'color');
        if (nestedColor) {
            return nestedColor;
        }

        // Fallback for payloads where color is only encoded in title text.
        return this.inferColorFromTitle(mediaItem.title);
    }

    findPrimaryColorForVariant(variantColor) {
        const directMatch = this.colorToPrimaryColorMap.get(variantColor);
        if (directMatch) {
            return directMatch;
        }

        const normalizedVariantColor = this.normalizeColor(variantColor);
        for (const [label, primaryColor] of this.colorToPrimaryColorMap.entries()) {
            if (this.normalizeColor(label) === normalizedVariantColor) {
                return primaryColor;
            }
        }
        return '';
    }

    getImageForVariantColor(variantColor, imageWithColorMap) {
        const normalizedVariantColor = this.normalizeColor(variantColor);
        if (!normalizedVariantColor || !imageWithColorMap?.size) {
            console.log('[xcProductDetailsSizeDisplay] image match', {
                rowColor: variantColor,
                normalizedRowColor: normalizedVariantColor,
                matchedImageUrl: '',
                reason: 'no-row-color-or-empty-map'
            });
            return '';
        }

        if (imageWithColorMap.has(normalizedVariantColor)) {
            const matchedImageUrl = imageWithColorMap.get(normalizedVariantColor);
            console.log('[xcProductDetailsSizeDisplay] image match', {
                rowColor: variantColor,
                normalizedRowColor: normalizedVariantColor,
                matchedImageUrl,
                matchType: 'direct'
            });
            return matchedImageUrl;
        }

        const mappedPrimaryColor = this.normalizeColor(this.findPrimaryColorForVariant(variantColor));
        if (mappedPrimaryColor && imageWithColorMap.has(mappedPrimaryColor)) {
            const matchedImageUrl = imageWithColorMap.get(mappedPrimaryColor);
            console.log('[xcProductDetailsSizeDisplay] image match', {
                rowColor: variantColor,
                normalizedRowColor: normalizedVariantColor,
                mappedPrimaryColor,
                matchedImageUrl,
                matchType: 'mapped-primary'
            });
            return matchedImageUrl;
        }

        console.log('[xcProductDetailsSizeDisplay] image match', {
            rowColor: variantColor,
            normalizedRowColor: normalizedVariantColor,
            mappedPrimaryColor,
            matchedImageUrl: '',
            reason: 'no-match'
        });
        return '';
    }

    coerceToString(value) {
        if (value == null) {
            return '';
        }
        if (typeof value === 'string') {
            return value.trim();
        }
        if (typeof value === 'object') {
            if (typeof value.value === 'string') {
                return value.value.trim();
            }
            if (typeof value.text === 'string') {
                return value.text.trim();
            }
        }
        return '';
    }

    findNestedStringByKey(target, keyFragment) {
        if (!target || typeof target !== 'object') {
            return '';
        }
        const needle = keyFragment.toLowerCase();
        const stack = [target];
        const visited = new Set();

        while (stack.length > 0) {
            const current = stack.pop();
            if (!current || typeof current !== 'object') {
                continue;
            }
            if (visited.has(current)) {
                continue;
            }
            visited.add(current);

            Object.keys(current).forEach((key) => {
                const value = current[key];
                if (key.toLowerCase().includes(needle)) {
                    const stringValue = this.coerceToString(value);
                    if (stringValue) {
                        stack.length = 0;
                        stack.push({ __found: stringValue });
                        return;
                    }
                }
                if (value && typeof value === 'object') {
                    stack.push(value);
                }
            });

            if (current.__found) {
                return current.__found;
            }
        }
        return '';
    }

    inferColorFromTitle(title) {
        const normalizedTitle = this.normalizeColor(title);
        if (!normalizedTitle) {
            return '';
        }

        const candidateColors = new Set();
        for (const [label, primaryColor] of this.colorToPrimaryColorMap.entries()) {
            const normalizedLabel = this.normalizeColor(label);
            const normalizedPrimary = this.normalizeColor(primaryColor);
            if (normalizedLabel) {
                candidateColors.add(normalizedLabel);
            }
            if (normalizedPrimary) {
                candidateColors.add(normalizedPrimary);
            }
        }

        // Safety fallback if color metadata hasn't loaded yet.
        [
            'red', 'pink', 'orange', 'yellow', 'green',
            'blue', 'purple', 'brown', 'black', 'grey', 'gray', 'white'
        ].forEach((color) => candidateColors.add(color));

        const sortedCandidates = Array.from(candidateColors).sort((a, b) => b.length - a.length);
        for (const color of sortedCandidates) {
            const pattern = new RegExp(`\\b${color.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i');
            if (pattern.test(normalizedTitle)) {
                return color;
            }
        }

        return '';
    }

    formatDate(inputDate) {
        /*var date = new Date(inputDate);
        if (!isNaN(date.getTime())) {
            // Months use 0 index.
            return date.getMonth() + 1 + '/' + date.getDate() + '/' + date.getFullYear();
        }*/
        if (!inputDate || typeof inputDate !== 'string') {
            return '';
        }
        if(inputDate.includes('-')) {
            let arrDate = inputDate.split('-');
            return arrDate[1] + '/' + arrDate[2] + '/' + arrDate[0];
        }
        return inputDate;
    }



    /*
    @api
    updateQtyFromSizeRun(sizeRun, sizeRunTotalQuantity){
        try{
            let productAggregates = {...this.productAggregates};
            let sizeRunObj = JSON.parse(sizeRun);
            let sizeNames = sizeRunObj.map(size => size.size);
            let sizeValues = sizeRunObj.map(size => size.quantity);
            let sumOfFactors = 0;
            for (let quantity of sizeValues){
                const quantityInt = parseInt(quantity);
                sumOfFactors += quantityInt;
            }
            // get matching col indices
            let matchingColIndices = [];
            let colIndex = 0;
            for(const colValue of this.productAggregates.colValues){
                if(sizeNames.includes(colValue.value)){
                    const templateIndex = sizeNames.indexOf(colValue.value);
                    matchingColIndices.push({'gridIndex': colIndex, 'templateIndex': templateIndex});
                }
                colIndex += 1;
            }
            if(matchingColIndices){
                for(const rowValue of this.productAggregates.rowValues){
                    for (const {gridIndex, templateIndex} of matchingColIndices) {
                        let cell = rowValue.keyMap[gridIndex];
                        let quantityInt = sizeValues[templateIndex];
                        const newCellQty = Math.round((quantityInt / sumOfFactors) * sizeRunTotalQuantity);
                        let availableQuantity = cell.quantity;
                        if (this.showInventory) {
                            if (availableQuantity > 0 && newCellQty < availableQuantity) {
                                cell.cellQty = newCellQty;
                            }
                            else if (newCellQty >= availableQuantity) {
                                cell.cellQty = availableQuantity;
                            }
                        }
                        else {
                            cell.cellQty = newCellQty;
                        }
                    }
                }
            }
            this.productAggregates = productAggregates;
        }
        catch(error){
            console.log(error);
        }

    }
    */
    @api
    updateQtyFromSizeRun(sizeRun, sizeRunFactor) {
        try {
            let sizeRunObj = JSON.parse(sizeRun);
            if (!Array.isArray(sizeRunObj) && sizeRunObj?.templateType === 'PRODUCT_GRID') {
                this.applyProductGridTemplate(sizeRunObj);
                return;
            }
            const sizeMap = new Map();
            let sizeIndex = 0;
            for(let sizeObj of sizeRunObj){
                sizeMap.set(sizeIndex, sizeObj.quantity);
                sizeIndex = sizeIndex + 1;
            }
                let rowIndex = 0;
                    for (let rowValue of this.productAggregates.rowValues) {
                        rowIndex = 0;
                        for (let keyVal of rowValue.keyMap) {
                            if(sizeMap.get(rowIndex) != null && !keyVal.disabled){
                             keyVal.cellQty = sizeMap.get(rowIndex);
                            }
                            rowIndex += 1;
                        }
                    }
        }
        catch (error) {
            console.log(error);
        }
    }

    applyProductGridTemplate(sizeRunObj) {
        if (!this.productAggregates?.rowValues) {
            return;
        }
        const productIdMap = new Map();
        const skuMap = new Map();
        for (const line of sizeRunObj.lines || []) {
            const quantity = Math.max(0, Number(line.quantity) || 0);
            if (line.productId) {
                productIdMap.set(String(line.productId), quantity);
            }
            if (line.sku) {
                skuMap.set(String(line.sku).toLowerCase(), quantity);
            }
        }

        for (let rowValue of this.productAggregates.rowValues) {
            for (let keyVal of rowValue.keyMap || []) {
                if (!keyVal || keyVal.disabled || !keyVal.showQtyBox) {
                    continue;
                }
                let nextQty = null;
                if (keyVal.prodId && productIdMap.has(String(keyVal.prodId))) {
                    nextQty = productIdMap.get(String(keyVal.prodId));
                } else if (keyVal.sku && skuMap.has(String(keyVal.sku).toLowerCase())) {
                    nextQty = skuMap.get(String(keyVal.sku).toLowerCase());
                } else {
                    nextQty = 0;
                }

                if (this.showInventory && keyVal.maxQuantity !== null && keyVal.maxQuantity !== undefined) {
                    const maxQty = Number(keyVal.maxQuantity) || 0;
                    nextQty = Math.min(nextQty, maxQty);
                }
                keyVal.cellQty = String(nextQty);
            }
        }
        this.productAggregates = {
            ...this.productAggregates,
            rowValues: [...this.productAggregates.rowValues]
        };
    }
    //  @wire(getProductSizes2, {productId: '$productId'})
    //  setAggregates({error, data}){
    //      if(data){
    //          console.log(data)
    //      }else{
    //          console.log(error)
    //      }
    //  }

    //  @wire(getProductSizes, {productId: '$productId'})
    //  setAggregates({error, data}){
    //      if (data) {
    //          this.productAggregates = {};
    //          this.productAggregates.colName = data.colName;
    //          this.productAggregates.rowName = data.rowName;
    //          this.productAggregates.colValues = data.colValues;

    //          let rowValues = [];

    //          for (var row of data.rowValues) {
    //              let keys = [];

    //              for (var key in row.keyMap) {
    //                  keys.push({
    //                      key: key,
    //                      value: row.keyMap[key]
    //                  });
    //              }

    //              rowValues.push({
    //                  value: row.value,
    //                  keyMap: keys
    //              });
    //          }

    //          this.productAggregates.rowValues = rowValues;
    //      }
    //      else if (error) {
    //          console.log(error);
    //      }
    //  }

     // Gets the normalized effective account of the user.
     get resolvedEffectiveAccountId() {
         const effectiveAccountId = this.effectiveAccountId || "";
         let resolved = null;

         if (effectiveAccountId.length > 0 && effectiveAccountId !== "000000000000000") {
             resolved = effectiveAccountId;
         }
         return resolved;
     }

	     quantityChangeHandler(event) {
	         const input = event.currentTarget || event.target;
	         let {rowidx: rowIdx, colidx: colIdx} = input.dataset;
	         let prodId = input.name;
	         let nextQty = this.getEventInputValue(event);

         if (!this.productAggregates || !this.productAggregates.rowValues) {
            return;
         }

         let parsedRowIdx = Number(rowIdx);
         let parsedColIdx = Number(colIdx);
         let row = this.productAggregates.rowValues[parsedRowIdx];
         let cell = row && row.keyMap ? row.keyMap[parsedColIdx] : null;

         if (!cell) {
            for (let rowVal of this.productAggregates.rowValues) {
                if (!rowVal.keyMap) {
                    continue;
                }
                let match = rowVal.keyMap.find((item) => item.key === prodId);
                if (match) {
                    match.cellQty = nextQty;
                    return;
                }
            }
            return;
         }

         cell.cellQty = nextQty === '' ? '0' : String(nextQty);
         // this shall be read from the bound vars as shown above
        //  if (event.target.value && event.target.value !== 0) {
        //      this.items[event.target.name] = {quantity: event.target.value, price: event.target.dataset.price};
        //  }
        //  else {
        //      delete this.items[event.target.name];
        //  }
	     }

	     syncVisibleQuantities() {
	         if (!this.productAggregates || !this.productAggregates.rowValues) {
	             return;
	         }

	         const inputs = this.getGridInputs();
	         const cells = this.getGridCells();
	         inputs.forEach((input) => {
	             const parsedRowIdx = Number(input.dataset.rowidx);
	             const parsedColIdx = Number(input.dataset.colidx);
	             const row = this.productAggregates.rowValues[parsedRowIdx];
	             const cell = row && row.keyMap ? row.keyMap[parsedColIdx] : cells[inputs.indexOf(input)];
	             if (!cell) {
	                 return;
	             }
	             cell.cellQty = input.value === '' ? '0' : String(input.value);
	         });
	     }

	     getGridCells() {
	         if (!this.productAggregates || !this.productAggregates.rowValues) {
	             return [];
	         }

	         return this.productAggregates.rowValues.reduce((cells, row) => {
	             if (!row || !row.keyMap) {
	                 return cells;
	             }
	             return cells.concat(row.keyMap.filter((cell) => cell.showQtyBox));
	         }, []);
	     }

	     getGridInputs() {
	         return Array.from(this.template.querySelectorAll('.sizeInputControl'))
	             .filter((input) => input.name);
	     }

	     getEventInputValue(event) {
	         if (event.composedPath) {
	             const nativeInput = event.composedPath().find((element) => element && element.tagName === 'INPUT');
	             if (nativeInput && nativeInput.value !== undefined) {
	                 return nativeInput.value;
	             }
	         }
	         if (event.detail && event.detail.value !== undefined) {
	             return event.detail.value;
	         }
	         return event.target ? event.target.value : '0';
	     }

	     getRenderedInputValue(input) {
	         const nativeInput = input.shadowRoot ? input.shadowRoot.querySelector('input') : null;
	         if (nativeInput && nativeInput.value !== undefined) {
	             return nativeInput.value;
	         }
	         return input.value;
	     }

	     getQuantityForInput(input, cell) {
	         const renderedValue = this.getRenderedInputValue(input);
	         const cellValue = cell ? cell.cellQty : null;
	         const wrapperValue = input.value;

	         for (const value of [renderedValue, cellValue, wrapperValue]) {
	             if (value === '' || value === null || value === undefined) {
	                 continue;
	             }
	             const quantity = Number(value);
	             if (!Number.isNaN(quantity) && quantity > 0) {
	                 return quantity;
	             }
	         }

	         return 0;
	     }

	     buildVisibleItemsToAdd() {
	         const inputs = this.getGridInputs();
	         const cells = this.getGridCells();
	         const visibleItems = {};

	         inputs.forEach((input, index) => {
	             const parsedRowIdx = Number(input.dataset.rowidx);
	             const parsedColIdx = Number(input.dataset.colidx);
	             const row = this.productAggregates && this.productAggregates.rowValues
	                 ? this.productAggregates.rowValues[parsedRowIdx]
	                 : null;
	             const cell = row && row.keyMap ? row.keyMap[parsedColIdx] : cells[index];
	             const quantity = this.getQuantityForInput(input, cell);
	             const productId = (cell && cell.prodId) || input.dataset.prodid;
	             if (!productId || input.disabled || !quantity || quantity <= 0) {
	                 return;
	             }

	             const existingQuantity = visibleItems[productId]
	                 ? Number(visibleItems[productId].quantity)
	                 : 0;

	             visibleItems[productId] = {
	                 quantity: String(existingQuantity + quantity),
	                 price: input.dataset.price || (cell && cell.price) || '0',
	                 inventoryItemId: input.dataset.inventoryitemid || (cell && cell.inventoryItemId) || null
	             };
	         });

	         return Object.keys(visibleItems).length > 0 ? visibleItems : this.items;
	     }

	     addToCart() {
	        // console.log("this.items, add to cart" + JSON.stringify(this.items));
	        //console.log("PDP size display CampignId: ", this.currentCampaignId);
	        if (this._addInFlight) {
	            return;
	        }
	        const itemsToAdd = this.buildVisibleItemsToAdd();
	        if(Object.keys(itemsToAdd).length > 0){
	            this._addInFlight = true;
            addItemsToCart({
                items : itemsToAdd,
                effectiveAccountId : this.resolvedEffectiveAccountId,
                currentCampaignId: this.campaignId
            })
            .then(result => {
                this._addInFlight = false;
                toast.show({
                    title: "Success!",
                    variant: 'Success',
                    mode: 'dismissable',
                    label: "Success",
                    message:
                      'Items successfully added to cart.',
                  }, this);
                publish(this.messageContext, refreshNotifications, {
                    initiatedFromAddToCart: true
                });
            })
            .catch(error => {
                console.log(error);
                this._addInFlight = false;
            });
        }
        else{
          //...
        }

     }

     handleAddToList() {
         this.dispatchEvent(new CustomEvent('addtolist', {
             detail: { productId: this.productId },
             bubbles: true,
             composed: true
         }));
     }

     getErrorMessage(error) {
        if (!error) {
            return 'An unknown error occurred.';
        }
        return error.body && error.body.message ? error.body.message : String(error.message || error);
     }
 }