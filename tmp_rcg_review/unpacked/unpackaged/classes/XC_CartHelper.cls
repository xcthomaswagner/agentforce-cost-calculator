public without sharing class XC_CartHelper {

    public static Map<String,Object> getCartSummary(String campaignId, String effectiveAccountId) {
        Map<String,Object> resultMap = new Map<String,Object>();

        String storeId = XC_Util_Query.currentWebStoreId;
        Boolean filterByAccount = String.isNotBlank(effectiveAccountId);
        
        List<XC_Cart__c> carts = new List<XC_Cart__c>();
        
        if(String.isNotBlank(campaignId)){
            carts = [
                    SELECT Id, Name,XC_Total_Amount__c, XC_Account__c,XC_Type__c,XC_Type_Reference_Id__c, XC_Total_Quantity__c,
                    (SELECT Id, XC_Unit_Price__c, XC_Quantity__c, XC_Cart__c, XC_Product__c, XC_Product__r.Name,
                    XC_Cart_Group__r.XC_Account__c, XC_Cart_Group__r.XC_Account__r.Name,XC_Product__r.StockKeepingUnit
                    FROM XC_Cart_Items__r ORDER BY XC_Product__r.Name ASC, XC_Cart_Group__r.XC_Account__r.Name ASC)               
                    FROM XC_Cart__c
                    WHERE OwnerId = :XC_Util_Query.currentUser.Id
                    AND XC_Type__c = 'Campaign' 
                    AND XC_Type_Reference_Id__c =: campaignId
                    AND XC_Status__c != 'Closed'
                    AND XC_Store__c =: storeId
                    ORDER BY LastModifiedDate DESC
                    LIMIT 1
            ];
        }else{
            carts = [
                    SELECT Id, Name,XC_Total_Amount__c, XC_Account__c,XC_Type__c,XC_Type_Reference_Id__c, XC_Total_Quantity__c,
                    (SELECT Id, XC_Unit_Price__c, XC_Quantity__c, XC_Cart__c, XC_Product__c, XC_Product__r.Name,XC_Product__r.ProductCode,
                    XC_Cart_Group__r.XC_Account__c, XC_Cart_Group__r.XC_Account__r.Name,XC_Product__r.StockKeepingUnit,XC_Product__r.ProductClass
                    FROM XC_Cart_Items__r ORDER BY XC_Product__r.Name ASC, XC_Cart_Group__r.XC_Account__r.Name ASC)               
                    FROM XC_Cart__c
                    WHERE OwnerId = :XC_Util_Query.currentUser.Id
                    AND XC_Status__c = 'Active'
                    AND XC_Store__c =: storeId
                    AND XC_Type__c != 'Campaign' 
                    ORDER BY LastModifiedDate DESC
                    LIMIT 1
            ];
        }   

        if(carts.size()>0) {
            resultMap.put('cartId', carts[0].Id);
            resultMap.put('cartTotalAmount', carts[0].XC_Total_Amount__c);
            resultMap.put('cartTotalQuantity', carts[0].XC_Total_Quantity__c);
            Integer lineCount = 0;
            if (filterByAccount) {
                Id accountIdFilter = (Id) effectiveAccountId;
                for (XC_Cart_Item__c item : carts[0].XC_Cart_Items__r) {
                    if (item.XC_Cart_Group__r.XC_Account__c == accountIdFilter) {
                        lineCount++;
                    }
                }
            } else {
                lineCount = carts[0].XC_Cart_Items__r.size();
            }
            resultMap.put('cartTotalLine', lineCount);
        }

        return resultMap;
    }

    public static String getCartContent(Boolean cartRePrice, String campaignId) {
        return getCartContent(cartRePrice, campaignId, null);
    }

    public static String getCartContent(Boolean cartRePrice, String campaignId, String effectiveAccountId) {
        Set<Id> productIds = new Set<Id>();
        String accountId = '';
        String storeId = XC_Util_Query.currentWebStoreId;
        
        List<XC_Cart__c> carts = new List<XC_Cart__c>();
        
        if(String.isNotBlank(campaignId)){
            carts = [
                    SELECT Id, Name,XC_Total_Amount__c, XC_Account__c,XC_Type__c,XC_Type_Reference_Id__c, XC_Total_Quantity__c,
                    (SELECT Id, XC_Unit_Price__c, XC_Quantity__c, XC_Cart__c, XC_Product__c, XC_Product__r.Name,XC_Product__r.ProductCode,
                    XC_Cart_Group__r.XC_Account__c, XC_Cart_Group__r.XC_Account__r.Name,XC_Product__r.StockKeepingUnit,XC_Product__r.ProductClass
                    FROM XC_Cart_Items__r ORDER BY XC_Product__r.Name ASC, XC_Cart_Group__r.XC_Account__r.Name ASC)               
                    FROM XC_Cart__c
                    WHERE OwnerId = :XC_Util_Query.currentUser.Id
                    AND XC_Type__c = 'Campaign' 
                    AND XC_Type_Reference_Id__c =: campaignId
                    AND XC_Status__c != 'Closed'
                    AND XC_Store__c =: storeId
                    ORDER BY LastModifiedDate DESC
                    LIMIT 1
            ];
        }else{
            carts = [
                    SELECT Id, Name,XC_Total_Amount__c, XC_Account__c,XC_Type__c,XC_Type_Reference_Id__c, XC_Total_Quantity__c,
                    (SELECT Id, XC_Unit_Price__c, XC_Quantity__c, XC_Cart__c, XC_Product__c, XC_Product__r.Name,XC_Product__r.ProductCode,
                    XC_Cart_Group__r.XC_Account__c, XC_Cart_Group__r.XC_Account__r.Name,XC_Product__r.StockKeepingUnit,XC_Product__r.ProductClass
                    FROM XC_Cart_Items__r ORDER BY XC_Product__r.Name ASC, XC_Cart_Group__r.XC_Account__r.Name ASC)               
                    FROM XC_Cart__c
                    WHERE OwnerId = :XC_Util_Query.currentUser.Id
                    AND XC_Status__c = 'Active'
                    AND XC_Store__c =: storeId
                    AND XC_Type__c != 'Campaign' 
                    ORDER BY LastModifiedDate DESC
                    LIMIT 1
            ];
        }   
       
        if (carts.isEmpty()) return null;
        
        accountId = carts[0].XC_Account__c;
        for(XC_Cart_Item__c cartItem : carts[0].XC_Cart_Items__r){
            productIds.add(cartItem.XC_Product__c);            
        }

        List<XC_Cart_Item__c> cartItems = carts[0].XC_Cart_Items__r;   
        Long dt1Process;
        Long dt2Process;
        dt1Process = DateTime.now().getTime();
        system.debug('start getColorsSizesFromChild Time');
        List<ProductAttribute> productVariants = XC_ProductUtil.getColorsSizesFromChild(productIds);    
        dt2Process = DateTime.now().getTime();
        Long millisecondsProcess = dt2Process - dt1Process;       
        system.debug('getColorsSizesFromChild milli elapsed: '  + millisecondsProcess);
        
        XC_CartWrapper.CartContent cartContents = new XC_CartWrapper.CartContent(carts[0], productVariants, effectiveAccountId);
        System.debug('[getCartContent] effectiveAccountId=' + effectiveAccountId + ' raw cartItems=' + cartContents.cartItems.size() + ' raw products=' + cartContents.products.size());
        if (String.isNotBlank(effectiveAccountId)) {
            cartContents.filterByAccount(effectiveAccountId);
        }
     
        return JSON.serialize(cartContents);

    }

    public static List<XC_Cart_Group__c> createCartGroups(String cartId, Set<String> accountIds){
        List<XC_Cart_Group__c> newCartGroups = new List<XC_Cart_Group__c>();

        for(String accountId : accountIds){
            XC_Cart_Group__c cartGroup = new XC_Cart_Group__c(
                XC_Account__c = accountId,
                XC_Cart__c = cartId
            );

            newCartGroups.add(cartGroup);
        }

        if(newCartGroups.size()>0){
            insert newCartGroups;
        }

        return newCartGroups;
    }

    public static Map<String,Object> getAccountCartGroupIds(String cartId){
        Map<String,Object> cartGroupsMap = new Map<String,Object>();
        List<XC_Cart_Group__c> cartGroups = [SELECT Id, XC_Account__c FROM XC_Cart_Group__c WHERE XC_Cart__c =: cartId];

        for(XC_Cart_Group__c cartGroup : cartGroups){
            cartGroupsMap.put(cartGroup.XC_Account__c, cartGroup.Id);
        }

        return cartGroupsMap;
    }

    public static List<XC_Cart_Item__c> getCartItems(String cartId){
        List<XC_Cart_Item__c> cartItems = [SELECT Id, XC_Product__c, XC_Cart_Group__r.XC_Account__c, XC_Unit_Price__c,XC_Quantity__c
                                            FROM XC_Cart_Item__c WHERE XC_Cart__c =: cartId];

        return cartItems;
    }

    public static void updateCartItems(String cartId, List<Map<String,Object>> inputList){
        User u = XC_Util_Query.currentUser;
        Map<String,Object> cartGroupsMap = getAccountCartGroupIds(cartId);
        Set<String> prodIds = new Set<String>();
        Map<String,Object> cartItemsMap = new Map<String,Object>();
        Set<String> needAccountIds = new Set<String>();
        List<XC_Cart_Item__c> updateCartItems = new List<XC_Cart_Item__c>();
        List<XC_Cart_Item__c> insertCartItems = new List<XC_Cart_Item__c>();
        List<XC_Cart_Item__c> deleteCartItems = new List<XC_Cart_Item__c>();
        
        for(Map<String,Object> inputMap : inputList){
            String prodId = (String)inputMap.get('productId');
            String acctId = (String)inputMap.get('accountId');
            prodIds.add(prodId);

            if(!cartGroupsMap.containsKey(acctId)){
                needAccountIds.add(acctId);
            }            
        }

        Map<String,Object> priceMap = XC_ProductUtil.getProductsPrice(prodIds, u.Contact.AccountId);  

        List<XC_Cart_Group__c> newCartGroups = createCartGroups(cartId,needAccountIds);

        for(XC_Cart_Group__c cartGroup: newCartGroups){ 
            cartGroupsMap.put(cartGroup.XC_Account__c,cartGroup.Id);
        }

        List<XC_Cart_Item__c> cartItems = getCartItems(cartId);        
        
        
        for(XC_Cart_Item__c cartItem : cartItems){
            String key = cartItem.XC_Product__c + '|'  + cartItem.XC_Cart_Group__r.XC_Account__c;
            cartItemsMap.put(key,cartItem);           
        }
        
        for(Map<String,Object> inputMap : inputList){
            String prodId = (String)inputMap.get('productId');
            String accId = (String)inputMap.get('accountId');
            Decimal quantity = (Decimal)inputMap.get('quantity');
            //String productSizeId = (String)inputMap.get('productSizeId');
            Boolean bError = false;
            Decimal unitPrice = 0;
            String key = prodId + '|' + accId;
            String productId15 = (prodId.length() == 18 ? prodId.Substring(0,prodId.length()-3) : prodId);
            Map<String,Object> prodPriceMap = new Map<String,Object>();
            //if(priceMap.containsKey(productId15)){
            if(priceMap.containsKey(prodId)){
                //prodPriceMap = (Map<String,Object>)priceMap.get(productId15);
                prodPriceMap = (Map<String,Object>)priceMap.get(prodId);
                unitPrice = (Decimal)prodPriceMap.get('unitPrice');
            }
   
            if(cartItemsMap.containsKey(key)){
                XC_Cart_Item__c updateCartItem = (XC_Cart_Item__c) cartItemsMap.get(key);
                if(quantity == 0){
                    deleteCartItems.add(updateCartItem);
                }else{                                 
                    updateCartItem.XC_Quantity__c = quantity;
                    updateCartItems.add(updateCartItem);
                }
                
            }else{
                if(quantity > 0){
                    XC_Cart_Item__c newCartItem = new XC_Cart_Item__c(                       
                        XC_Unit_Price__c = unitPrice,
                        XC_Quantity__c = quantity,
                        XC_Product__c = prodId,
                        XC_Cart_Group__c = (String)cartGroupsMap.get(accId),
                        XC_Cart__c = cartId
                    );

                    insertCartItems.add(newCartItem);
                }                
            }

        }

        if(updateCartItems.size()>0){
            update updateCartItems;
        }

        if(insertCartItems.size()>0){
            insert insertCartItems;
        }

        if(deleteCartItems.size()>0){
            delete deleteCartItems;
        }

    }

    public static void removeCartProducts(List<Map<String,Object>> productIds, String cartId, String effectiveAccountId){
        Set<String> parentIds = new Set<String>();
        Set<String> prodIds = new Set<String>();
        Set<String> deleteProductIds = new Set<String>();
        for(Map<String,Object> prodMap : productIds){
            for(String prodKey : prodMap.keySet()){
                 parentIds.add(prodKey);
                 deleteProductIds.add(prodKey + prodMap.get(prodKey));
            }           
        }        

        List<ProductAttribute> paList = [SELECT Id, ProductId, Color__c, VariantParentId FROM ProductAttribute WHERE VariantParentId in : parentIds];
        
        for(ProductAttribute pa : paList){
            String prodKey = pa.VariantParentId + pa.Color__c;
            if(deleteProductIds.contains(prodKey)){                
                prodIds.add(pa.ProductId);                
            }
        }

        prodIds.addAll(parentIds);

        List<XC_Cart_Item__c> items;
        if (String.isNotBlank(effectiveAccountId)) {
            items = [
                    SELECT Id
                    FROM XC_Cart_Item__c
                    WHERE 
                    XC_Product__c in :prodIds
                    AND XC_Cart__c = :cartId
                    AND XC_Cart_Group__r.XC_Account__c = :effectiveAccountId
            ];
        } else {
            items = [
                    SELECT Id
                    FROM XC_Cart_Item__c
                    WHERE 
                    XC_Product__c in :prodIds
                    AND XC_Cart__c = :cartId
            ];
        }

        delete items;
    }

    public static void removeAllCartProducts(String cartId, String effectiveAccountId){
        List<XC_Cart_Item__c> items;
        if (String.isNotBlank(effectiveAccountId)) {
            items = [
                    SELECT Id
                    FROM XC_Cart_Item__c
                    WHERE XC_Cart__c = :cartId
                    AND XC_Cart_Group__r.XC_Account__c = :effectiveAccountId
            ];
        } else {
            items = [
                    SELECT Id
                    FROM XC_Cart_Item__c
                    WHERE XC_Cart__c = :cartId
            ];
        }

        delete items;
    }

    public static Map<String,Object> cartValidation(String cartId){
        Decimal minAmount = 0;
        Decimal minQuantities = 0;
        List<String> errorList = new List<String>();
        Map<String,Object> validationMap = new Map<String,Object>{
            'Success' => true
        };

        XC_Cart__c cartDetail = [SELECT Id, XC_Type__c, XC_Type_Reference_Id__c, XC_Total_Amount__c, XC_Total_Quantity__c FROM XC_Cart__c WHERE Id =: cartId];

        if(cartDetail.XC_Type__c == 'Campaign' && cartDetail.XC_Type_Reference_Id__c != null){
            XC_Campaign__c campaign = [SELECT Id, XC_Order_Minimum_Amount__c, XC_Order_SKU_Minimum_Quantity__c FROM XC_Campaign__c WHERE Id =: cartDetail.XC_Type_Reference_Id__c];
            minAmount = (campaign.XC_Order_Minimum_Amount__c > 0 ? campaign.XC_Order_Minimum_Amount__c : 0);  
            minQuantities = (campaign.XC_Order_SKU_Minimum_Quantity__c > 0 ? campaign.XC_Order_SKU_Minimum_Quantity__c : 0);
            
            if(minAmount > 0){
                if(cartDetail.XC_Total_Amount__c < minAmount){
                    errorList.add('This cart has a minimum order amount of ' + String.valueOf(campaign.XC_Order_Minimum_Amount__c));
                }
            }

            if(minQuantities > 0){
                if(cartDetail.XC_Total_Quantity__c < minQuantities){
                    errorList.add('This cart has a minimum order quantities of ' + String.valueOf(minQuantities));
                }
            }
        }

        Map<String, Object> atOnceValidationMap = atOnceOrderCreditValidation(cartId, null);
        if(atOnceValidationMap.containsKey('errorList')){
            errorList.addAll((List<String>)atOnceValidationMap.get('errorList'));
        }

        if(errorList.size()>0){
            validationMap.put('Success', false);
            validationMap.put('errorList', errorList);
        }

        return validationMap;

    }

    public static Map<String, Object> atOnceOrderCreditValidation(String cartId, String effectiveAccountId) {
        List<String> errorList = new List<String>();
        Map<String, Object> validationMap = new Map<String, Object>{
            'Success' => true
        };

        try {
            XC_Cart__c cartDetail = [
                SELECT Id, XC_Type__c, XC_Total_Amount__c, XC_Account__c,
                       (SELECT Id, XC_Account__c FROM XC_Cart_Groups__r)
                FROM XC_Cart__c
                WHERE Id = :cartId
                LIMIT 1
            ];

            // Only validate At-Once orders (non-Campaign)
            if (cartDetail.XC_Type__c != 'Campaign') {
                // Resolve the account to validate against
                Id accountIdToValidate = String.isNotBlank(effectiveAccountId)
                    ? (Id) effectiveAccountId
                    : cartDetail.XC_Account__c;

                // Find the cart group for the effective account
                Id targetGroupId = null;
                for (XC_Cart_Group__c cg : cartDetail.XC_Cart_Groups__r) {
                    if (cg.XC_Account__c == accountIdToValidate) {
                        targetGroupId = cg.Id;
                        break;
                    }
                }

                // Compute order total from the effective account's cart group items only
                Decimal orderTotal = 0;
                if (targetGroupId != null) {
                    for (XC_Cart_Item__c item : [
                        SELECT XC_Quantity__c, XC_Unit_Price__c
                        FROM XC_Cart_Item__c
                        WHERE XC_Cart_Group__c = :targetGroupId
                    ]) {
                        Decimal qty   = item.XC_Quantity__c   == null ? 0 : item.XC_Quantity__c;
                        Decimal price = item.XC_Unit_Price__c == null ? 0 : item.XC_Unit_Price__c;
                        orderTotal += (qty * price);
                    }
                } else {
                    // Fallback: use cart-level total if no group found
                    orderTotal = cartDetail.XC_Total_Amount__c != null ? cartDetail.XC_Total_Amount__c : 0;
                }

                BuyerAccount buyerAccount = [
                    SELECT Id, AvailableCredit, CreditLimit, CurrentBalance, MinimumOrderLimit, MaximumOrderLimit
                    FROM BuyerAccount
                    WHERE BuyerId = :accountIdToValidate
                    LIMIT 1
                ];

                // Available credit: use AvailableCredit field; fall back to CreditLimit - CurrentBalance
                Decimal availableCredit = buyerAccount.AvailableCredit != null
                    ? buyerAccount.AvailableCredit
                    : ((buyerAccount.CreditLimit      == null ? 0 : buyerAccount.CreditLimit) -
                       (buyerAccount.CurrentBalance   == null ? 0 : buyerAccount.CurrentBalance));

                Decimal minimumLimit = buyerAccount.MinimumOrderLimit != null ? buyerAccount.MinimumOrderLimit : 0;
                Decimal maximumLimit = buyerAccount.MaximumOrderLimit != null ? buyerAccount.MaximumOrderLimit : 0;

                // 1. Available credit check
                if (orderTotal > availableCredit) {
                    errorList.add('Order total ($' + orderTotal.setScale(2) +
                                  ') exceeds available credit ($' + availableCredit.setScale(2) + ').');
                }

                // 2. Minimum order limit
                if (minimumLimit > 0 && orderTotal < minimumLimit) {
                    errorList.add('Order total ($' + orderTotal.setScale(2) +
                                  ') is below the minimum order limit ($' + minimumLimit.setScale(2) + ').');
                }

                // 3. Maximum order limit
                if (maximumLimit > 0 && orderTotal > maximumLimit) {
                    errorList.add('Order total ($' + orderTotal.setScale(2) +
                                  ') exceeds the maximum order limit ($' + maximumLimit.setScale(2) + ').');
                }

                if (!errorList.isEmpty()) {
                    validationMap.put('Success', false);
                    validationMap.put('errorList', errorList);
                }
            }

        } catch (QueryException qe) {
            errorList.add('BuyerAccount not found for this account. Please contact support.');
            validationMap.put('Success', false);
            validationMap.put('errorList', errorList);
        } catch (Exception e) {
            errorList.add('An error occurred during credit validation: ' + e.getMessage());
            validationMap.put('Success', false);
            validationMap.put('errorList', errorList);
        }

        return validationMap;
    }

    public static Map<String, Object> getActiveCart(String effectiveAccountId, String currentCampaignId)
    {
        String storeId = XC_Util_Query.currentWebStoreId;
        User u = XC_Util_Query.currentUser;
        String userId = u != null ? u.Id : '';
        String query = 
        'SELECT Id, XC_Type__c,	XC_Type_Reference_Id__c,'
        + ' (SELECT Id, XC_Account__c FROM XC_Cart_Groups__r),'
        + ' (SELECT XC_Product__c, XC_Quantity__c, XC_Cart_Group__c FROM XC_Cart_Items__r)'
        + ' FROM XC_Cart__c' 
        + ' WHERE OwnerId =: userId AND XC_Store__c =: storeId';

        String active =  ' AND XC_Status__c = \'Active\' LIMIT 1';
        //String regular = ' AND XC_Status__c = \'Open\' AND XC_Type__c != \'Campaign\' LIMIT 1';
        String campaign =  ' AND XC_Status__c = \'Open\' AND XC_Type__c = \'Campaign\''
        + ' AND XC_Type_Reference_Id__c != null'
        + ' AND XC_Type_Reference_Id__c =: currentCampaignId LIMIT 1' ;

        query = (String.isNotBlank(currentCampaignId) ? query + campaign : query + active);

        List<XC_Cart__c> activeCarts = Database.query(query);

        //List<XC_Cart__c> openRegularCarts = Database.query(query + regular);
        //List<XC_Cart__c> openCampaignCarts = Database.query(query + campaign);

        XC_Cart__c cart;
        Id cartGroupId;

        // cart and cart group

        if (activeCarts.isEmpty()) {
            cart = new XC_Cart__c(Name='New Cart', XC_Status__c = 'Active', XC_Store__c = storeId, XC_Account__c =  effectiveAccountId);
            if(String.isNotBlank(currentCampaignId)){
                cart.Name = 'New Campaign Cart';
                cart.XC_Type__c = 'Campaign';
                cart.XC_Status__c = 'Open';
                cart.XC_Type_Reference_Id__c = currentCampaignId;
            }
            insert cart;
                
            XC_Cart_Group__c hmcg = new XC_Cart_Group__c(XC_Account__c = effectiveAccountId, XC_Cart__c = cart.Id);
            insert hmcg;
            cartGroupId = hmcg.Id;
        }
        else {
            cart = activeCarts[0];         

            Map<Id,Id> cartGroupIdByAccountId = new Map<Id,Id>();
            for (XC_Cart_Group__c cg : cart.XC_Cart_Groups__r) {
                System.debug(cg);
                cartGroupIdByAccountId.put(cg.XC_Account__c, cg.Id);
            }
            if (cartGroupIdByAccountId.containsKey(effectiveAccountId)) {
                System.debug('CART GROUP EXISTS');
                cartGroupId = cartGroupIdByAccountId.get(effectiveAccountId);
            }else {
                System.debug('CART GROUP DOES NOT EXISTS');
                XC_Cart_Group__c hmcg = new XC_Cart_Group__c(XC_Account__c = effectiveAccountId, XC_Cart__c = cart.Id);
                insert hmcg;
                cartGroupId = hmcg.Id;
            }
        }

        return new Map<String, Object>{'cart' => cart, 'cartGroupId' => cartGroupId};
    }

    public static void addToCartGrid2(
            List<String> productIds,
            Map<String, String> quantity,
            Map<String, String> price,
            String effectiveAccountId)
    {
        
        String storeId = XC_Util_Query.currentWebStoreId;
        User u = XC_Util_Query.currentUser;        
        List<XC_Cart__c> activeCarts  = [SELECT Id,
        (SELECT Id, XC_Account__c FROM XC_Cart_Groups__r), 
        (SELECT XC_Product__c, XC_Quantity__c, XC_Cart_Group__c FROM XC_Cart_Items__r) 
        FROM XC_Cart__c 
        WHERE OwnerId =: u.Id AND XC_Store__c =: storeId AND XC_Status__c = 'Active' LIMIT 1];
        
      
        XC_Cart__c cart;
        Id cartGroupId;

        if (activeCarts.isEmpty()) {
            
            cart = new XC_Cart__c(Name='New Cart', XC_Status__c = 'Active', XC_Store__c = storeId, XC_Account__c =  effectiveAccountId);
            insert cart;

            XC_Cart_Group__c hmcg = new XC_Cart_Group__c(XC_Account__c = effectiveAccountId, XC_Cart__c = cart.Id);
            insert hmcg;

            cartGroupId = hmcg.Id;
        }
        else {
            cart = activeCarts[0];
            Map<Id,Id> cartGroupIdByAccountId = new Map<Id,Id>();

            for (XC_Cart_Group__c cg : cart.XC_Cart_Groups__r) {
                System.debug(cg);
                cartGroupIdByAccountId.put(cg.XC_Account__c, cg.Id);
            }
    
            if (cartGroupIdByAccountId.containsKey(effectiveAccountId)) {
                System.debug('CART GROUP EXISTS');
                cartGroupId = cartGroupIdByAccountId.get(effectiveAccountId);
            }
            else {
                System.debug('CART GROUP DOES NOT EXISTS');
                XC_Cart_Group__c hmcg = new XC_Cart_Group__c(XC_Account__c = effectiveAccountId, XC_Cart__c = cart.Id);
                insert hmcg;
    
                cartGroupId = hmcg.Id;
            }
        }
        List<XC_Cart_Item__c> cartItemsToUpsert = new List<XC_Cart_Item__c>();

        System.debug(productIds);
        if(cart.XC_Cart_Items__r != null) {  
            System.debug('Cart Items not null');
            for(String prodId : productIds){
                Boolean updated = false;
                for(XC_Cart_Item__c ci : cart.XC_Cart_Items__r){
                    if(ci.XC_Product__c == prodId && ci.XC_Cart_Group__c == cartGroupId) {
                        ci.XC_Quantity__c += Decimal.valueOf(quantity.get(prodId));
                        cartItemsToUpsert.add(ci);
                        updated = true;
                    }
                }
                if(!updated){
                    cartItemsToUpsert.add(new XC_Cart_Item__c(
                        XC_Product__c = prodId,
                        XC_Cart__c = cart.Id,
                        XC_Cart_Group__c = cartGroupId,
                        XC_Quantity__c = Decimal.valueOf(quantity.get(prodId)),
                        XC_Unit_Price__c = (String.isNotBlank(price.get(prodId)) && price.get(prodId) != 'undefined' && price.get(prodId) != 'null') ? Decimal.valueOf(price.get(prodId)) : 0                    
                ));
            }
                
            }
        }
        else{
            System.debug('cart items null');
            for(String prodId : productIds){
                System.debug(prodId);
                        cartItemsToUpsert.add(new XC_Cart_Item__c(
                        XC_Product__c = prodId,
                        XC_Cart__c = cart.Id,
                        XC_Cart_Group__c = cartGroupId,
                        XC_Quantity__c = Decimal.valueOf(quantity.get(prodId)),
                        XC_Unit_Price__c = (String.isNotBlank(price.get(prodId)) && price.get(prodId) != 'undefined' && price.get(prodId) != 'null') ? Decimal.valueOf(price.get(prodId)) : 0                    
                ));
            }
        }

        upsert cartItemsToUpsert;

        System.debug('UPSERT FINISHED');
    }

    
    public static void addToCartGrid(
            List<String> productIds,
            Map<String, String> quantity,
            Map<String, String> price,
            String effectiveAccountId,
            String currentCampaignId)
    {
        addToCartGrid(productIds, quantity, price, effectiveAccountId, currentCampaignId, new Map<String, String>());
    }

    public static void addToCartGrid(
            List<String> productIds,
            Map<String, String> quantity,
            Map<String, String> price,
            String effectiveAccountId,
            String currentCampaignId,
            Map<String, String> inventoryItemIds)
    {


        Map<String, Object> result = getActiveCart(effectiveAccountId, currentCampaignId);
        
        XC_Cart__c cart = (XC_Cart__c) result.get('cart');
        String cartGroupId = (String) result.get('cartGroupId');

        // Do not link inventory items for Prebook campaigns (they have no inventory records)
        Boolean isPrebook = false;
        if (String.isNotBlank(currentCampaignId)) {
            List<XC_Campaign__c> campaigns = [SELECT XC_Order_Type__c FROM XC_Campaign__c WHERE Id = :currentCampaignId LIMIT 1];
            isPrebook = !campaigns.isEmpty() && campaigns[0].XC_Order_Type__c == 'Prebook';
        }

        // cart items
        List<XC_Cart_Item__c> cartItemsToUpsert = new List<XC_Cart_Item__c>();

        System.debug(productIds);
        if(cart.XC_Cart_Items__r != null) {  
            System.debug('Cart Items not null');
            for(String prodId : productIds){
                Boolean updated = false;
                for(XC_Cart_Item__c ci : cart.XC_Cart_Items__r){
                    if(ci.XC_Product__c == prodId && ci.XC_Cart_Group__c == cartGroupId) {
                        ci.XC_Quantity__c += Decimal.valueOf(quantity.get(prodId));
                        if(!isPrebook && inventoryItemIds.containsKey(prodId) && String.isNotBlank(inventoryItemIds.get(prodId))){
                            ci.XC_Inventory_Item__c = (Id) inventoryItemIds.get(prodId);
                        }
                        cartItemsToUpsert.add(ci);
                        updated = true;
                    }
                }
                if(!updated){
                    Id invId = (!isPrebook && inventoryItemIds.containsKey(prodId) && String.isNotBlank(inventoryItemIds.get(prodId))) ? (Id) inventoryItemIds.get(prodId) : null;
                    cartItemsToUpsert.add(new XC_Cart_Item__c(
                        XC_Product__c = prodId,
                        XC_Cart__c = cart.Id,
                        XC_Cart_Group__c = cartGroupId,
                        XC_Quantity__c = Decimal.valueOf(quantity.get(prodId)),
                        XC_Unit_Price__c = (String.isNotBlank(price.get(prodId)) && price.get(prodId) != 'undefined' && price.get(prodId) != 'null') ? Decimal.valueOf(price.get(prodId)) : 0,
                        XC_Inventory_Item__c = invId
                ));
            }
                
            }
        }
        else{
            System.debug('cart items null');
            for(String prodId : productIds){
                System.debug(prodId);
                        Id invId = (!isPrebook && inventoryItemIds.containsKey(prodId) && String.isNotBlank(inventoryItemIds.get(prodId))) ? (Id) inventoryItemIds.get(prodId) : null;
                        cartItemsToUpsert.add(new XC_Cart_Item__c(
                        XC_Product__c = prodId,
                        XC_Cart__c = cart.Id,
                        XC_Cart_Group__c = cartGroupId,
                        XC_Quantity__c = Decimal.valueOf(quantity.get(prodId)),
                        XC_Unit_Price__c = (String.isNotBlank(price.get(prodId)) && price.get(prodId) != 'undefined' && price.get(prodId) != 'null') ? Decimal.valueOf(price.get(prodId)) : 0,
                        XC_Inventory_Item__c = invId
                ));
            }
        }

        upsert cartItemsToUpsert;

        System.debug('UPSERT FINISHED');
    }

    public static void addItemsToCart(Map<String, Map<String, String>> items, String effectiveAccountId, String currentCampaignId) {
        if (!items.isEmpty()) {
            try {
                List<User> users = [SELECT ContactId FROM User WHERE Id =: UserInfo.getUserId() LIMIT 1];
                System.debug('[addItemsToCart] effectiveAccountId received=' + effectiveAccountId);
                Id contactId = users[0].ContactId;
                System.debug('[addItemsToCart] contactId=' + contactId);
                List<String> productIds = new List<String>();
                productIds.addAll(items.keySet());
                Map<String, String> quantity = new Map<String, String>();
                Map<String, String> price = new Map<String, String>();
                Map<String, String> inventoryItemIds = new Map<String, String>();
                System.debug('addItemsToCart:items: ' + items);
                // Add sizes to cart
                for (String productId : items.keySet()) {
                    Map<String, Object> itemValue = (Map<String, Object>) items.get(productId);
                    quantity.put( productId, (String) itemValue.get('quantity') );
                    price.put( productId, (String) itemValue.get('price'));
                    if(itemValue.containsKey('inventoryItemId') && itemValue.get('inventoryItemId') != null){
                        inventoryItemIds.put(productId, (String) itemValue.get('inventoryItemId'));
                    }
                }
                createTask(contactId, productIds, 'ADD_ITEMS_TO_CART');
                addToCartGrid(productIds, quantity, price, effectiveAccountId, currentCampaignId, inventoryItemIds);
            } catch (Exception e) {
                throw new AuraHandledException(e.getLineNumber() + ':' + e.getMessage() + ':' + e.getStackTraceString());
            }
        }
    }
    
    public static void createTask(Id contactId, List<String> productIds, String taskType){
        if(contactId != null){
            Task taskRec = new Task();
            taskRec.WhoId = contactId;
            taskRec.Subject = taskType.equalsIgnoreCase('ADD_ITEMS_TO_CART') ? 'ADD_ITEMS_TO_CART' : 'CHECKOUT';
            taskRec.Description = taskRec.Subject + '-' + String.join(productIds, ';');
            taskRec.Status = 'Completed';
            System.debug('Creating task');
            insert taskRec;
            System.debug('taskRec Id::'+taskRec.Id);
            System.debug('taskRec ::'+taskRec);
        }
    }

    /*public static ConnectApi.CartItem addItemToCart(String productId, String quantity, String effectiveAccountId) {
        ConnectApi.CartItemInput cartInput = new ConnectApi.CartItemInput();
        cartInput.productId = productId;
        cartInput.quantity = quantity;
        cartInput.type = ConnectApi.CartItemType.PRODUCT;

        ConnectApi.CartItem result = ConnectApi.CommerceCart.addItemToCart(
                XC_Util_Query.currentWebStoreId,
                effectiveAccountId,
                'active',
                cartInput
        );

        return result;
    }*/


    public static Map<String, Object> processImportedLineSheet(List<String> skus)
    {
        System.debug('XC_LWC_CartCtrlHelper:processImportedLineSheet start');

        System.debug('XC_LWC_CartCtrlHelper:processImportedLineSheet: skus: ' + skus);


        Map<String, Object> productsResult = XC_ProductUtil.getVariationProductsFromSKU(skus);

        Map<String, List<XC_LWC_PDPController.ProductVariation>> productVariationsList = ( Map<String, List<XC_LWC_PDPController.ProductVariation>>) productsResult.get('productVariationsList');

        Map<String, String> productSKUToIdMap = (Map<String, String>) productsResult.get('productSKUToIdMap');

        Map<String, Object> priceMap =  (Map<String, Object>) productsResult.get('priceMap');


        System.debug('XC_LWC_CartCtrlHelper:processImportedLineSheet: productsResult: ' + productsResult);

        System.debug('XC_LWC_CartCtrlHelper:processImportedLineSheet: productsResult.productVariationsList: ' + productVariationsList);

        System.debug('XC_LWC_CartCtrlHelper:processImportedLineSheet: productSKUToIdMap: '+ productSKUToIdMap);

        System.debug('XC_LWC_CartCtrlHelper:processImportedLineSheet: productSKUToIdMap: '+ priceMap);

        return new Map<String, Object> {
            'productVariationsList' => productsResult.get('productVariationsList'), 
            'priceMap' => productsResult.get('priceMap'),
            'productSKUToIdMap' => productSKUToIdMap
        };
    }

    public static void addImportedLinesheetToCart(Map<Id, Integer> itemsToAdd, Map<String, Decimal> priceMap){
        
        System.debug('XC_LWC_CartCtrlHelper:addImportedLinesheetToCart: enter');

        System.debug('XC_LWC_CartCtrlHelper:addImportedLinesheetToCart: itemsToAdd: '+ itemsToAdd);

        System.debug('XC_LWC_CartCtrlHelper:addImportedLinesheetToCart: priceMap: '+ priceMap);

        User u = [SELECT Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId()];
        String effectiveAccountId = u.Contact.AccountId;

        System.debug('XC_LWC_CartCtrlHelper:addImportedLinesheetToCart: effectiveAccountId: '+ effectiveAccountId);


        Map<String, Object> cartResult = getActiveCart(effectiveAccountId, '');

        System.debug('XC_LWC_CartCtrlHelper:addImportedLinesheetToCart: cartResult: '+ cartResult);


        XC_Cart__c cart = (XC_Cart__c) cartResult.get('cart');
        String cartGroupId = (String) cartResult.get('cartGroupId');

        // cart items
        List<XC_Cart_Item__c> cartItemsToUpsert = new List<XC_Cart_Item__c>();

        if(cart.XC_Cart_Items__r != null) {  
            System.debug('XC_LWC_CartCtrlHelper:addImportedLinesheetToCart: cart is not empty');
            for(String productId : itemsToAdd.keySet()){
                Boolean updated = false;
                Integer quantity = (Integer) itemsToAdd.get(productId);
                for(XC_Cart_Item__c ci : cart.XC_Cart_Items__r){
                    if(ci.XC_Product__c == productId && ci.XC_Cart_Group__c == cartGroupId) {
                        ci.XC_Quantity__c += quantity;
                        cartItemsToUpsert.add(ci);
                        updated = true;
                    }
                }
                if(!updated){
                    cartItemsToUpsert.add(new XC_Cart_Item__c(
                        XC_Product__c = productId,
                        XC_Cart__c = cart.Id,
                        XC_Cart_Group__c = cartGroupId,
                        XC_Quantity__c = quantity,
                        XC_Unit_Price__c = priceMap.get(productId)                   
                    ));
                }
            }
        }
        else{
            System.debug('XC_LWC_CartCtrlHelper:addImportedLinesheetToCart: cart is empty');
            for(String productId : itemsToAdd.keySet()){
                cartItemsToUpsert.add(new XC_Cart_Item__c(
                XC_Product__c = productId,
                XC_Cart__c = cart.Id,
                XC_Cart_Group__c = cartGroupId,
                XC_Quantity__c = itemsToAdd.get(productId),
                XC_Unit_Price__c = priceMap.get(productId)                 
            ));
            }
        }
        upsert cartItemsToUpsert;
        System.debug('UPSERT FINISHED');
    }

    @AuraEnabled
    public static void reOrder(String orderSummaryId, String effectiveAccountId){
        try{
            OrderSummary orderSummary = [
                SELECT Id, SalesStoreId
                FROM OrderSummary
                WHERE Id = :orderSummaryId
                LIMIT 1
            ];
            if (orderSummary.SalesStoreId != null) {
                XC_Util_Query.storeId = String.valueOf(orderSummary.SalesStoreId);
            }

            Map<String, Map<String, String>> items = new Map<String, Map<String, String>>();
            List<OrderItemSummary> orderSummaries = [
                SELECT Id, Product2Id, Quantity, ListPrice 
                FROM OrderItemSummary 
                WHERE OrderSummaryId =: orderSummaryId
            ];
            for(OrderItemSummary item: orderSummaries){
                Map<String, String> prodInfo = new Map<String, String>();
                prodInfo.put('quantity', String.valueOf(item.Quantity));
                prodInfo.put('price', String.valueOf(item.ListPrice));
                items.put(item.Product2Id, prodInfo);
            }
            closeMyCarts();
            addItemsToCart(items, effectiveAccountId, '');
        }
        catch(Exception ex){
            throw new AuraHandledException(ex.getMessage());
        }
    }

    private static void closeMyCarts(){
        String storeId = XC_Util_Query.currentWebStoreId;
        User u = XC_Util_Query.currentUser;
        String userId = u != null ? u.Id : '';
        String query = 
        'SELECT Id, XC_Type__c,	XC_Type_Reference_Id__c,XC_Status__c'
        + ' FROM XC_Cart__c' 
        + ' WHERE OwnerId =: userId AND XC_Store__c =: storeId';
        String active =  ' AND XC_Status__c = \'Active\' LIMIT 1';
        List<XC_Cart__c> activeCarts = Database.query(query + active);
        for(XC_Cart__c cart: activeCarts){
            cart.XC_Status__c = 'Closed';
        }
        upsert activeCarts;
    }

    /*public static Map<String, Object> changeActiveCart(String effectiveAccountId, String currentCampaignId)
    {
        String storeId = XC_Util_Query.currentWebStoreId;
        User u = XC_Util_Query.currentUser;
        String userId = u != null ? u.Id : '';
        String query = 
        'SELECT Id, XC_Type__c,	XC_Type_Reference_Id__c,'
        + ' (SELECT Id, XC_Account__c FROM XC_Cart_Groups__r),'
        + ' (SELECT XC_Product__c, XC_Quantity__c, XC_Cart_Group__c FROM XC_Cart_Items__r)'
        + ' FROM XC_Cart__c' 
        + ' WHERE OwnerId =: userId AND XC_Store__c =: storeId';

        String active =  ' AND XC_Status__c = \'Active\' LIMIT 1';
        //String regular = ' AND XC_Status__c = \'Open\' AND XC_Type__c != \'Campaign\' LIMIT 1';
        String campaign =  ' AND XC_Status__c = \'Open\' AND XC_Type__c = \'Campaign\''
        + ' AND XC_Type_Reference_Id__c != null'
        + ' AND XC_Type_Reference_Id__c =: currentCampaignId LIMIT 1' ;

        query = (String.isNotBlank(currentCampaignId) ? query + campaign : query + active);

        List<XC_Cart__c> activeCarts = Database.query(query);

        //List<XC_Cart__c> openRegularCarts = Database.query(query + regular);
        //List<XC_Cart__c> openCampaignCarts = Database.query(query + campaign);

        XC_Cart__c cart;
        Id cartGroupId;

        // cart and cart group

        if (activeCarts.isEmpty()) {
            cart = new XC_Cart__c(Name='New Cart', XC_Status__c = 'Active', XC_Store__c = storeId, XC_Account__c =  effectiveAccountId);
            if(String.isNotBlank(currentCampaignId)){
                cart.Name = 'New Campaign Cart';
                cart.XC_Type__c = 'Campaign';
                cart.XC_Status__c = 'Open';
                cart.XC_Type_Reference_Id__c = currentCampaignId;
            }
            insert cart;
                
            XC_Cart_Group__c hmcg = new XC_Cart_Group__c(XC_Account__c = effectiveAccountId, XC_Cart__c = cart.Id);
            insert hmcg;
            cartGroupId = hmcg.Id;
        }
        else {
            cart = activeCarts[0];         

            Map<Id,Id> cartGroupIdByAccountId = new Map<Id,Id>();
            for (XC_Cart_Group__c cg : cart.XC_Cart_Groups__r) {
                System.debug(cg);
                cartGroupIdByAccountId.put(cg.XC_Account__c, cg.Id);
            }
            if (cartGroupIdByAccountId.containsKey(effectiveAccountId)) {
                System.debug('CART GROUP EXISTS');
                cartGroupId = cartGroupIdByAccountId.get(effectiveAccountId);
            }else {
                System.debug('CART GROUP DOES NOT EXISTS');
                XC_Cart_Group__c hmcg = new XC_Cart_Group__c(XC_Account__c = effectiveAccountId, XC_Cart__c = cart.Id);
                insert hmcg;
                cartGroupId = hmcg.Id;
            }
        }

        return new Map<String, Object>{'cart' => cart, 'cartGroupId' => cartGroupId};
    }*/

    public static void changeColor(String cartId, String originalColor, String replacementColor){
        Map<String, Decimal> quantityMap =  new Map<String, Decimal>();
        Map<String, String> colorMap =  new Map<String, String>();
        Map<String, String> sizeMap =  new Map<String, String>();
        Map<String, XC_Cart_Item__c> productIdToCartItemMap =  new Map<String, XC_Cart_Item__c>();
        Map<String, Map<String, String>> attribsMap = new Map<String, Map<String, String>> ();
        Map<String, String> childParentIdMap = new Map<String, String>();
        List<XC_Cart_Item__c> updateList = new List<XC_Cart_Item__c>();
        List<XC_Cart_Item__c> deleteList = new List<XC_Cart_Item__c>();

        List <XC_Cart__c> carts = [
            SELECT Id, XC_Type__c, XC_Type_Reference_Id__c,
            (SELECT XC_Product__c, XC_Quantity__c, XC_Cart_Group__c FROM XC_Cart_Items__r)
            FROM XC_Cart__c
            WHERE Id =: cartId
        ];
        if(carts.size() > 0){
            for(XC_Cart_Item__c cartItem: carts[0].XC_Cart_Items__r){
                quantityMap.put(cartItem.XC_Product__c, cartItem.XC_Quantity__c);
            }
        }
        List<ProductAttribute> attributes = [
            SELECT Id, Name, ProductId, Color__c, Size__c, VariantParentId 
            FROM ProductAttribute
            WHERE ProductId IN :quantityMap.keySet()
        ];
        for(ProductAttribute attribute: attributes){
            String parentId = attribute.VariantParentId;
            String childId = attribute.ProductId;
            String color = attribute.Color__c;
            String size = attribute.Size__c;
            childParentIdMap.put(childId, parentId);
            if(attribsMap.get(parentId) != null){
                attribsMap.get(parentId).put(color + '-' + size, childId);
            }
            else{
                attribsMap.put(parentId, new Map<String, String>{color + '-' + size => childId});
            }
            colorMap.put(attribute.ProductId, attribute.Color__c);
            sizeMap.put(attribute.ProductId, attribute.Size__c);
        }
        for(XC_Cart_Item__c cartItem: carts[0].XC_Cart_Items__r){
            String childId = cartItem.XC_Product__c;
            productIdToCartItemMap.put(childId, cartItem);
        }

        for(XC_Cart_Item__c cartItem: carts[0].XC_Cart_Items__r){
            String childId = cartItem.XC_Product__c;
            String parentId = childParentIdMap.get(childId);
            Map<String, String> childrenMap = attribsMap.get(parentId);
            String color = colorMap.get(childId);
            String size = sizeMap.get(childId);
            if(color == originalColor){
                String replacementProdId;
                replacementProdId = childrenMap.get(replacementColor + '-' + size);
                XC_Cart_Item__c replacementCartItem = productIdToCartItemMap.get(replacementProdId);
                replacementCartItem.XC_Quantity__c += 1;
                cartItem.XC_Quantity__c = 0;
                updateList.add(replacementCartItem);
                deleteList.add(cartItem);   
            }   
        }
        update updateList;
        delete deleteList;
        // System.debug('changeColor: quantityMap: ' + quantityMap);
        // System.debug('changeColor: colorMap: ' + colorMap);
        // System.debug('changeColor: updateList: ' + updateList);
        // System.debug('changeColor: deleteList: ' + deleteList);
    }

    /*public static List<ConnectApi.BatchResult> addItemsToCart2(Map<String,String> items, String effectiveAccountId) {
        List<ConnectApi.BatchInput> cartItems = new List<ConnectApi.BatchInput>();

        for (String productId : items.keySet()) {
            String qty = items.get(productId);

            if (String.isBlank(qty)) continue;

            ConnectApi.CartItemInput item = new ConnectApi.CartItemInput();
            item.productId = productId;
            item.quantity = items.get(productId);
            item.type = ConnectApi.CartItemType.PRODUCT;

            cartItems.add(new ConnectApi.BatchInput(item));
        }

        List<ConnectApi.BatchResult> results = ConnectApi.CommerceCart.addItemsToCart(XC_Util_Query.currentWebStoreId, effectiveAccountId, 'active', cartItems);

        return results;
    }*/

    public static void addItemsToCart3(Map<String, Map<String, String>> items, String effectiveAccountId) {
        if (!items.isEmpty()) {
            try {

                List<String> productIds = new List<String>();
                productIds.addAll(items.keySet());
                Map<String, String> quantity = new Map<String, String>();
                Map<String, String> price = new Map<String, String>();
                System.debug(items);
                // Add sizes to cart
                for (String productId : items.keySet()) {
                    Map<String, Object> itemValue = (Map<String, Object>) items.get(productId);
                    
                    quantity.put( productId, (String) itemValue.get('quantity') );
                    price.put( productId, (String) itemValue.get('price'));
                }



                XC_CartHelper.addToCartGrid2(productIds, quantity, price, effectiveAccountId);
            } catch (Exception e) {
                throw new AuraHandledException(e.getLineNumber() + ':' + e.getMessage() + ':' + e.getStackTraceString());
            }
        }
    }
}
