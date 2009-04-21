#property copyright "slacktrader"
#property link      "slacktrader"

#include <gMail.mqh>
#include <stderror.mqh>
#include <stdlib.mqh>
#include <StringLib.mqh>

bool        _DEBUG =                   true;

//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
// screenshot functionality
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
#define     _FILES_DIRECTORY           "C:\\Program Files\\XTB-Trader 4\\experts\\files\\"
#define     _SCREENSHOT_X_SIZE         1600
#define     _SCREENSHOT_Y_SIZE         1200
#define     _AUTO_SCREENSHOT_PERIOD    PERIOD_H1

//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
// main variables                                                         
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
int   _MIN_STOPLOSS_DISTANCE        = 10;
int   _MIN_TAKEPROFIT_DISTANCE      = 10;

//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
// MM Modul                                                         
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
#define     _MM_FIX_LOT                         1
#define     _MM_FIX_PERC                        2
#define     _MM_FIX_PERC_AVG_LAST_PROFIT        3
#define     _MM_FIX_PERC_CNT_MAX_DD             4

#define     _MINLOTS                            0.1
#define     _MAXLOTS                            5
#define     _DEFAULT_LOTS                       0.1
#define     _DEFAULT_SLIPPAGE                   3
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
// Send mail notification modul
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
#define     _MAIL_NOTIFICATION_FROM          "turtle.vpscustomer.com"
#define     _MAIL_NOTIFICATION_TO            "radorybar@gmail.com"
#define     _SENT_MAIL_NOTIFI_ON_ERROR       0
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
// Trendline order auto management modul
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------

//define all important action language keywords
/*
#define BUY_STOP				     "BUY_STOP"
#define BUY_LIMIT               "BUY_LIMIT"
#define SELL_STOP               "SELL_STOP"
#define SELL_LIMIT              "SELL_LIMIT"
#define SEND_MAIL               "SEND_MAIL"
#define SEND_SCREENSHOT         "SEND_SCREENSHOT"
#define ORDER_CLOSE             "ORDER_CLOSE"
#define OBJECT_ACTIVATE         "OBJECT_ACTIVATE"
#define OBJECT_DEACTIVATE       "OBJECT_DEACTIVATE"
#define ORDER_MOVE_SL           "ORDER_MOVE_SL"
#define ORDER_MOVE_TP           "ORDER_MOVE_TP"
#define ORDER_ID                "ORDER_ID"
*/

#define BUY_STOP				     "BUYSTOP"
#define BUY_LIMIT               "BUYLIMIT"
#define SELL_STOP               "SELLSTOP"
#define SELL_LIMIT              "SELLLIMIT"
#define SEND_MAIL               "MAIL"
#define SEND_SCREENSHOT         "SCREEN"
#define ORDER_CLOSE             "ORDRCLOSE"
#define OBJECT_ACTIVATE         "OBJACT"
#define OBJECT_DEACTIVATE       "OBJDEACT"
#define ORDER_MOVE_SL           "ORDRSL"
#define ORDER_MOVE_TP           "ORDRTP"
#define ORDER_ID                "ORDRID"

//All object that are relevant for autotarder
int       _OBJECT_TYPES[] = 
{
   OBJ_TREND, 
   OBJ_HLINE
};

//ACTION LANGUAGE Definition
//All actions possible for use in object description
string   _ACTION_LANGUAGE_COMMANDS[] = 
{
   BUY_STOP,
//usage: BUY_STOP*ORDER_ID new odred id[*SEND_MAIL [text of mail][*SEND_SCREENSHOT [text for screenshot]]]

   BUY_LIMIT,
//usage: BUY_LIMIT*ORDER_ID new odred id[*SEND_MAIL [text of mail][*SEND_SCREENSHOT [text for screenshot]]]

   SELL_STOP,
//usage: SELL_STOP*ORDER_ID new odred id[*SEND_MAIL [text of mail][*SEND_SCREENSHOT [text for screenshot]]]

   SELL_LIMIT,
//usage: SELL_LIMIT*ORDER_ID new odred id[*SEND_MAIL [text of mail][*SEND_SCREENSHOT [text for screenshot]]]

   SEND_MAIL,
//usage: SEND_MAIL [text of mail][*SEND_SCREENSHOT [text for screenshot]]]

   SEND_SCREENSHOT,
//usage: [*SEND_SCREENSHOT [text for screenshot]]

   ORDER_CLOSE,
//usage: ORDER_CLOSE*ORDER_ID odred id to close[*SEND_MAIL [text of mail][*SEND_SCREENSHOT [text for screenshot]]]

   OBJECT_ACTIVATE,
//usage: OBJECT_ACTIVATE object id to activate[*SEND_MAIL [text of mail][*SEND_SCREENSHOT [text for screenshot]]]

   OBJECT_DEACTIVATE,
//usage: OBJECT_DEACTIVATE object id to deactivate[*SEND_MAIL [text of mail][*SEND_SCREENSHOT [text for screenshot]]]

   ORDER_MOVE_SL,
//usage: ORDER_MOVE_SL value of new SL*ORDER_ID order id for new SL[*SEND_MAIL [text of mail][*SEND_SCREENSHOT [text for screenshot]]]

   ORDER_MOVE_TP
//usage: ORDER_MOVE_TP value of new TP*ORDER_ID order id for new TP[*SEND_MAIL [text of mail][*SEND_SCREENSHOT [text for screenshot]]]
};

//All other - non actions - possible for use in object description
string   _ACTION_LANGUAGE_ITEMS[] = 
{
   ORDER_ID
};

string _ACTION_LANGUAGE_DELIMITER = "*";

int _MAX_ACTION_LANGUAGE_ITEMS = 100;

static double LASTASK;
static double LASTBID;

string UsedOrderIDsInfo = "";

//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
int init()
{
   _MIN_STOPLOSS_DISTANCE           = MarketInfo(Symbol(), MODE_STOPLEVEL);
   _MIN_TAKEPROFIT_DISTANCE         = MarketInfo(Symbol(), MODE_STOPLEVEL);
   
   LASTASK = Ask;
   LASTBID = Bid;

   return(0);
}
int deinit()
{
   return(0);
}

int start()
{
   int i = 0;
   string RelevantObjectNames[];
   string AskCrossedObjectNames[];
   string BidCrossedObjectNames[];
   string AskActionStrings[];
   string BidActionStrings[];
   string AllActionStrings[];
   string ParsedActions[];
   
   if(iVolume(Symbol(), _AUTO_SCREENSHOT_PERIOD, 0) == 1)
      MakeScreenShot();
   
   if(LASTASK == Ask && LASTBID == Bid)
      return(0);
   
   //should return all object names - ids which are relevant for autotrader
   if(!GetRelevantObjects(_OBJECT_TYPES, RelevantObjectNames))
      return(1);
   
   //should filter and return only all active object names
   if(!FilterActiveObjects(RelevantObjectNames))
      return(2);

   //should return all object names - ids which were crossed by Ask price
   if(!GetAskCrossedObjects(RelevantObjectNames, AskCrossedObjectNames))
      return(3);

   //should return all object names - ids which were crossed by Bid price
   if(!GetBidCrossedObjects(RelevantObjectNames, BidCrossedObjectNames))
      return(4);

   //should parse all Ask cross actions from all Ask crossed objects
   if(!GetActionStrings(AskCrossedObjectNames, AskActionStrings))
      return(5);
   
   //should parse all Bid cross actions from all Bid crossed objects
   if(!GetActionStrings(BidCrossedObjectNames, BidActionStrings))
      return(6);

   //should execute all actions in pool
   for(i = 0; i < ArraySize(AskActionStrings); i++)
   {
      if(ParseActions(AskActionStrings[i], ParsedActions))
         ExecuteActions(AskCrossedObjectNames[i], ParsedActions, true);
   }
   for(i = 0; i < ArraySize(BidActionStrings); i++)
   {
      if(ParseActions(BidActionStrings[i], ParsedActions))
         ExecuteActions(BidCrossedObjectNames[i], ParsedActions, false);
   }
   
//should parse all actions from all objects
//Get all used order IDs from active orders and from all relevant objects
   UsedOrderIDsInfo = UsedOrderIDs();

   if(!GetActionStrings(RelevantObjectNames, AllActionStrings))
      return(7);
   for(i = 0; i < ArraySize(AllActionStrings); i++)
   {
      if(ParseActions(AllActionStrings[i], ParsedActions))
         UsedOrderIDsInfo = StringConcatenate(UsedOrderIDsInfo, "\n", ParseOrderIdFromActionString(ParsedActions));
   }

   Comment(UsedOrderIDsInfo);
   
   LASTASK = Ask;
   LASTBID = Bid;

   return(0);
}
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
// Trendline order auto management modul
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
bool GetRelevantObjects(int OBJECT_TYPES[], string& RelevantObjectNames[])
{
   bool result = true;
   ArrayResize(RelevantObjectNames, 0);
   
   for(int i = 0; i < ObjectsTotal(); i++)
   {
      for(int j = 0; j < ArraySize(OBJECT_TYPES); j++)
      {
         
         if(ObjectType(ObjectName(i)) == OBJECT_TYPES[j])
         {
//            Print("i: ", i, " j: ", j, " ObjectName: ", ObjectName(i), " OBJECT_TYPES[j]: ", OBJECT_TYPES[j]);
            ArrayResize(RelevantObjectNames, ArraySize(RelevantObjectNames) + 1);
            RelevantObjectNames[ArraySize(RelevantObjectNames) - 1] = ObjectName(i);
            break;
         }
      }
   }

   return(result);
}


bool FilterActiveObjects(string& ActiveObjectNames[])
{
   bool result = true;
   string AllObjectNames[];
   
   ArrayCopy(AllObjectNames, ActiveObjectNames);
   
   ArrayResize(ActiveObjectNames, 0);
   
   for(int j = 0; j < ArraySize(AllObjectNames); j++)
   {
      if(IsActiveObject(AllObjectNames[j]))
      {
         ArrayResize(ActiveObjectNames, ArraySize(ActiveObjectNames) + 1);
         ActiveObjectNames[ArraySize(ActiveObjectNames) - 1] = AllObjectNames[j];
      }
   }

   return(result);
}

bool IsActiveObject(string ObjName)
{
   bool result = true;
   
   if(StringFind(StringTrimLeft(StringTrimRight(ObjectDescription(ObjName))), "-") == 0)
      result = false;
      
   return(result);
}

bool GetAskCrossedObjects(string RelevantObjectNames[], string& CrossedObjectNames[])
{
   bool result = true;

   ArrayResize(CrossedObjectNames, 0);
   
   for(int i = 0; i < ArraySize(RelevantObjectNames); i++)
   {
//      Print("i: ", i, " RelevantObjectNames[i]: ", RelevantObjectNames[i], " ObjectGetValueByShift(RelevantObjectNames[i], 0): ", ObjectGetValueByShift(RelevantObjectNames[i], 0), " PriceCrossedValue(ObjectGetValueByShift(RelevantObjectNames[i], 0), true): ", PriceCrossedValue(ObjectGetValueByShift(RelevantObjectNames[i], 0), true));

      if(PriceCrossedValue(RelevantObjectNames[i], true))
      {
         ArrayResize(CrossedObjectNames, ArraySize(CrossedObjectNames) + 1);
         CrossedObjectNames[ArraySize(CrossedObjectNames) - 1] = RelevantObjectNames[i];
      }
   }

   return(result);
}

bool GetBidCrossedObjects(string RelevantObjectNames[], string& CrossedObjectNames[])
{
   bool result = true;
   ArrayResize(CrossedObjectNames, 0);

   for(int i = 0; i < ArraySize(RelevantObjectNames); i++)
   {
      if(PriceCrossedValue(RelevantObjectNames[i], false))
      {
         ArrayResize(CrossedObjectNames, ArraySize(CrossedObjectNames) + 1);
         CrossedObjectNames[ArraySize(CrossedObjectNames) - 1] = RelevantObjectNames[i];
      }
   }

   return(result);
}

bool PriceCrossedValue(string ObjName, bool AskBid)
{
   bool result = false;
   double Value = 0;   
   
   if(ObjectType(ObjName) == OBJ_TREND)
      Value = ObjectGetValueByShift(ObjName, 0);
   else if(ObjectType(ObjName) == OBJ_HLINE)
      Value = ObjectGet(ObjName, OBJPROP_PRICE1);
   else
      Value = ObjectGetValueByShift(ObjName, 0);
   
   if(AskBid)
   {
      if(Ask >= Value && LASTASK <= Value)
         result = true;
      if(Ask <= Value && LASTASK >= Value)
         result = true;
   }
   else
   {
      if(Bid <= Value && LASTBID >= Value)
         result = true;
      if(Bid >= Value && LASTBID <= Value)
         result = true;
   }

   return(result);
}

bool GetActionStrings(string CrossedObjectNames[], string& ActionStrings[])
{
   bool result = true;
   ArrayResize(ActionStrings, 0);
   
   for(int i = 0; i < ArraySize(CrossedObjectNames); i++)
   {
      ArrayResize(ActionStrings, i + 1);
      ActionStrings[i] = GetActionString(CrossedObjectNames[i]);
   }

   return(result);
}

string GetActionString(string ObjName)
{
   string result = "";
   
   result = StringTrimLeft(StringTrimRight(ObjectDescription(ObjName)));
   if(StringFind(result, "-") == 0)
      result = StringSubstr(result, 1);
   
   return(result);
}

bool ParseActions(string ActionString, string& ParsedAction[])
{
   bool result = true;
   string RestActionString = "";
   
   ArrayResize(ParsedAction, 0);
   
   int i = 0;
   
   while(i < _MAX_ACTION_LANGUAGE_ITEMS)
   {
      ArrayResize(ParsedAction, i + 1);

//Parse first action language item and its parameters in rest ActionString
//next delimiter position is:
      int NextDelimiterIndex = StringFind(ActionString, _ACTION_LANGUAGE_DELIMITER) + 1;
//Parsed acion is whole string up to delimiter position      
      ParsedAction[i] = StringTrimLeft(StringTrimRight(StringSubstr(ActionString, 0, NextDelimiterIndex - 1)));

//Check if parsed string contains any valid action or non action keyword
      bool ValidAcionLanguageItem = false;
      for(int j = 0; j < ArraySize(_ACTION_LANGUAGE_COMMANDS); j++)
         if(stringContainsIgnoreCase(ParsedAction[i], _ACTION_LANGUAGE_COMMANDS[j]))
         {
            ValidAcionLanguageItem = true;
            break;
         }
      if(!ValidAcionLanguageItem)
         for(j = 0; j < ArraySize(_ACTION_LANGUAGE_ITEMS); j++)
            if(stringContainsIgnoreCase(ParsedAction[i], _ACTION_LANGUAGE_ITEMS[j]))
            {
               ValidAcionLanguageItem = true;
               break;
            }
         
      if(!ValidAcionLanguageItem)
         break;

//The rest of action string for next parse cycle, without already parsed actions ,blanks and delimiters
      if(NextDelimiterIndex != 0)
         ActionString = StringTrimLeft(StringTrimRight(StringSubstr(ActionString, NextDelimiterIndex)));
      else
         break;                  

      i++;
   }

//MAX _MAX_ACTION_LANGUAGE_ITEMS parsed, otherwise finish with error
//if action string contains parts without any valid action language item, finish with error
   if(i == _MAX_ACTION_LANGUAGE_ITEMS || !ValidAcionLanguageItem)
      result = false;

/*
   if(_DEBUG)
   {
      Print("ParsedAction");
      DebugStringArray(ParsedAction);
   }
*/

   return(result);
}

bool ExecuteActions(string ObjName, string ParsedAction[], bool AskBid)
{
   bool result = false;
   int i = 0;
   int OrderID = 0, NumberOfPosition = 0, NumberOfClosedPosition = 0;
   string parsedtext, screenshotname;
   
   screenshotname = MakeScreenShot();

//determine ORDER_ID of processed action, if there is any defined
//if there is Order ID deined in action string - it has to be an integer value otherwise cancel action and return error
   if(ContainsAction(ParsedAction, ORDER_ID, parsedtext))
   {
      if(StrToInteger(parsedtext) > 0)
         OrderID = StrToInteger(parsedtext);
      else
      {
         Print("Error converting Order ID");
         return(result);
      }
   }

   UsedOrderIDsInfo = StringConcatenate(UsedOrderIDsInfo, "\n", OrderID);
   
/*   
   if(_DEBUG)
   {
      Print("ParsedAction");
      DebugStringArray(ParsedAction);
   }
*/

// BUY
//if Ask price crossed
   if(AskBid)
   {
      int OrderTicketNumber = 0;
      if(Ask > LASTASK)
         if(stringContainsIgnoreCase(ParsedAction[0], BUY_STOP))
         {
            OrderTicketNumber = OpenPosition(false, _DEFAULT_LOTS, 0, 0, _DEFAULT_SLIPPAGE, OrderID);
            if(OrderTicketNumber < 0)
               ErrorCheckup();
            else
            {
               result = true;
               ObjectDeactivate(ObjName);
               if(ContainsAction(ParsedAction, SEND_MAIL, parsedtext))
               {
                  Print(StringConcatenate("Order ", OrderTicketNumber, " - BUY ", Symbol(), " at : ", Ask), StringConcatenate(ParsedAction[0], ": ", parsedtext));
                  SendPredefinedRecipientMail(StringConcatenate("Order ", OrderTicketNumber, " - BUY ", Symbol(), " at : ", Ask), StringConcatenate(ParsedAction[0], ": ", parsedtext));
               }
               if(ContainsAction(ParsedAction, SEND_SCREENSHOT, parsedtext))
                  SendPredefinedRecipientMail(StringConcatenate("Order ", OrderTicketNumber, " - BUY ", Symbol(), " at : ", Ask), StringConcatenate(ParsedAction[0], ": ", parsedtext), StringConcatenate(_FILES_DIRECTORY, screenshotname), screenshotname);
            }
         }

      if(Ask < LASTASK)
         if(stringContainsIgnoreCase(ParsedAction[0], BUY_LIMIT))
         {
            OrderTicketNumber = OpenPosition(false, _DEFAULT_LOTS, 0, 0, _DEFAULT_SLIPPAGE, OrderID);
            if(OrderTicketNumber < 0)
               ErrorCheckup();
            else
            {
               result = true;
               ObjectDeactivate(ObjName);
               if(ContainsAction(ParsedAction, SEND_MAIL, parsedtext))
                  SendPredefinedRecipientMail(StringConcatenate("Order ", OrderTicketNumber, " - BUY ", Symbol(), " at : ", Ask), StringConcatenate(ParsedAction[0], ": ", parsedtext));
               if(ContainsAction(ParsedAction, SEND_SCREENSHOT, parsedtext))
                  SendPredefinedRecipientMail(StringConcatenate("Order ", OrderTicketNumber, " - BUY ", Symbol(), " at : ", Ask), StringConcatenate(ParsedAction[0], ": ", parsedtext), StringConcatenate(_FILES_DIRECTORY, screenshotname), screenshotname);
            }
         }
   }

// SELL
//if Bid price crossed
   else
   {
      if(Bid < LASTBID)
         if(stringContainsIgnoreCase(ParsedAction[0], SELL_STOP))
         {
            OrderTicketNumber = OpenPosition(true, _DEFAULT_LOTS, 0, 0, _DEFAULT_SLIPPAGE, OrderID);
            if(OrderTicketNumber < 0)
               ErrorCheckup();
            else
            {
               result = true;
               ObjectDeactivate(ObjName);
               if(ContainsAction(ParsedAction, SEND_MAIL, parsedtext))
                  SendPredefinedRecipientMail(StringConcatenate("Order ", OrderTicketNumber, " - SELL ", Symbol(), " at : ", Bid), StringConcatenate(ParsedAction[0], ": ", parsedtext));
               if(ContainsAction(ParsedAction, SEND_SCREENSHOT, parsedtext))
                  SendPredefinedRecipientMail(StringConcatenate("Order ", OrderTicketNumber, " - SELL ", Symbol(), " at : ", Bid), StringConcatenate(ParsedAction[0], ": ", parsedtext), StringConcatenate(_FILES_DIRECTORY, screenshotname), screenshotname);
            }
         }

      if(Bid > LASTBID)
         if(stringContainsIgnoreCase(ParsedAction[0], SELL_LIMIT))
         {
            OrderTicketNumber = OpenPosition(true, _DEFAULT_LOTS, 0, 0, _DEFAULT_SLIPPAGE, OrderID);
            if(OrderTicketNumber < 0)
               ErrorCheckup();
            else
            {
               result = true;
               ObjectDeactivate(ObjName);
               if(ContainsAction(ParsedAction, SEND_MAIL, parsedtext))
                  SendPredefinedRecipientMail(StringConcatenate("Order ", OrderTicketNumber, " - SELL ", Symbol(), " at : ", Bid), StringConcatenate(ParsedAction[0], ": ", parsedtext));
               if(ContainsAction(ParsedAction, SEND_SCREENSHOT, parsedtext))
                  SendPredefinedRecipientMail(StringConcatenate("Order ", OrderTicketNumber, " - SELL ", Symbol(), " at : ", Bid), StringConcatenate(ParsedAction[0], ": ", parsedtext), StringConcatenate(_FILES_DIRECTORY, screenshotname), screenshotname);
            }
         }
   }
   
//ORDER_CLOSE
   if(stringContainsIgnoreCase(ParsedAction[0], ORDER_CLOSE))
   {
//if Ask price crossed
      if(AskBid)
      {
//OrderID can be a ticket number
         if(OrderSelect(OrderID, SELECT_BY_TICKET) == true)
         {
            NumberOfPosition = 1;
            NumberOfClosedPosition = ClosePosition(OrderID);
         }
//if OrderID is not a Ticketnumber - it can be a MAGICNUMBER
         else
         {
            NumberOfPosition = getOrdersTotalByMagicnumber(OrderID);
            NumberOfClosedPosition = CloseAllShortPositions(OrderID);
         }
         Print("AskBid: ", AskBid, " NumberOfPosition: ", NumberOfPosition, ", NumberOfClosedPosition: ", NumberOfClosedPosition);
         if(NumberOfClosedPosition != NumberOfPosition)
         {
            SendPredefinedRecipientMail(StringConcatenate("Error closing position: ", OrderID), StringConcatenate("Error closing position: ", OrderID, " - number of closed position returned: ", NumberOfClosedPosition));
         }
         else
         {
            result = true;
            ObjectDeactivate(ObjName);
            if(ContainsAction(ParsedAction, SEND_MAIL, parsedtext))
               SendPredefinedRecipientMail(StringConcatenate("Order ", OrderID, " closed at: ", Ask), StringConcatenate(ParsedAction[0], ": ", parsedtext));
            if(ContainsAction(ParsedAction, SEND_SCREENSHOT, parsedtext))
               SendPredefinedRecipientMail(StringConcatenate("Order ", OrderID, " closed at: ", Ask), StringConcatenate(ParsedAction[0], ": ", parsedtext), StringConcatenate(_FILES_DIRECTORY, screenshotname), screenshotname);
         }
      }
      
      if(!AskBid)
      {
         NumberOfPosition = getOrdersTotalByMagicnumber(OrderID);
         NumberOfClosedPosition = CloseAllLongPositions(OrderID);
         Print("AskBid: ", AskBid, " NumberOfPosition: ", NumberOfPosition, ", NumberOfClosedPosition: ", NumberOfClosedPosition);
         if(NumberOfClosedPosition != NumberOfPosition)
         {
            SendPredefinedRecipientMail(StringConcatenate("Error closing position: ", OrderID), StringConcatenate("Error closing position: ", OrderID, " - number of closed position returned: ", NumberOfClosedPosition));
         }
         else
         {
            result = true;
            ObjectDeactivate(ObjName);
            if(ContainsAction(ParsedAction, SEND_MAIL, parsedtext))
               SendPredefinedRecipientMail(StringConcatenate("Order ", OrderID, " closed at: ", Bid), StringConcatenate(ParsedAction[0], ": ", parsedtext));
            if(ContainsAction(ParsedAction, SEND_SCREENSHOT, parsedtext))
               SendPredefinedRecipientMail(StringConcatenate("Order ", OrderID, " closed at: ", Bid), StringConcatenate(ParsedAction[0], ": ", parsedtext), StringConcatenate(_FILES_DIRECTORY, screenshotname), screenshotname);
         }
      }
   }

   if(stringContainsIgnoreCase(ParsedAction[0], OBJECT_ACTIVATE))
   {
      
   }

   if(stringContainsIgnoreCase(ParsedAction[0], OBJECT_DEACTIVATE))
   {
      
   }

   if(stringContainsIgnoreCase(ParsedAction[0], ORDER_MOVE_SL))
   {
      
   }

   if(stringContainsIgnoreCase(ParsedAction[0], ORDER_MOVE_TP))
   {
      
   }

   bool sent;
//SEND_MAIL   
   if(stringContainsIgnoreCase(ParsedAction[0], SEND_MAIL))
   {
      sent = SendPredefinedRecipientMail("Mail notification", ParseActionText(ParsedAction[0]));
      if(!sent)
         ErrorCheckup();
      ObjectDeactivate(ObjName);
   }

//SEND_SCREENSHOT
   if(stringContainsIgnoreCase(ParsedAction[0], SEND_SCREENSHOT))
   {
      sent = SendPredefinedRecipientMail("Mail notification with screenshot attached", ParseActionText(ParsedAction[0]), StringConcatenate(_FILES_DIRECTORY, screenshotname), screenshotname);
      if(!sent)
         ErrorCheckup();
      ObjectDeactivate(ObjName);
   }

   return(result);
}

bool ContainsAction(string ParsedAction[], string Action, string& ActionText)
{
   bool result = false;
   
   for(int i = 0; i < ArraySize(ParsedAction); i++)
   {
      if(stringContainsIgnoreCase(ParsedAction[i], Action))
      {
         ActionText = ParseActionText(ParsedAction[i]);
         result = true;
         break;
      }
   }

//   Print("function-ContainsAction ParsedAction: ", ParsedAction[i], " Action: ", Action, " ActionText: ", ActionText);
   return(result);
}

bool ObjectDeactivate(string ObjName)
{
   bool result = false;
   
   result = ObjectSetText(ObjName, StringConcatenate("-", ObjectDescription(ObjName)));
   if(result)
      Print("Object ", ObjName, ", ", StringSubstr(ObjectDescription(ObjName), 1), " - Deactivated successfully.");
   else
      ErrorCheckup();
   
   return(result);
}

string ParseActionText(string ActionItem)
{
   string result = "";

   
//search for all action keywords, and parse only text behind this keyword   
   for(int j = 0; j < ArraySize(_ACTION_LANGUAGE_COMMANDS); j++)
   {
//      Print(stringToLowerCase(ActionItem), " ", stringToLowerCase(_ACTION_LANGUAGE_COMMANDS[j]), " ", StringFind(stringToLowerCase(ActionItem), stringToLowerCase(_ACTION_LANGUAGE_COMMANDS[j])) > -1);
      if(stringContainsIgnoreCase(ActionItem, _ACTION_LANGUAGE_COMMANDS[j]))
      {
//         Print("ActionItem: ", ActionItem, " _ACTION_LANGUAGE_COMMANDS[j]: ", _ACTION_LANGUAGE_COMMANDS[j]);
//if action keyword found, cut it from the result action text
         result = StringTrimLeft(StringTrimRight(StringSubstr(ActionItem, stringFindIgnoreCase(ActionItem, _ACTION_LANGUAGE_COMMANDS[j]) + StringLen(_ACTION_LANGUAGE_COMMANDS[j]) + 1)));
         
//if after action keyword follows one of these letters, cut it also - it is a kind of delimiter for better readibility
         if(
            StringFind(result, ":") == 0 || 
            StringFind(result, "-") == 0
         )
         result = StringSubstr(result, 1);
      }
   }

//if still no keyword has been found
   if(StringLen(result) == 0)
      for(j = 0; j < ArraySize(_ACTION_LANGUAGE_ITEMS); j++)
      {
//         Print(stringToLowerCase(ActionItem), " ", stringToLowerCase(_ACTION_LANGUAGE_ITEMS[j]), " ", StringFind(stringToLowerCase(ActionItem), stringToLowerCase(_ACTION_LANGUAGE_ITEMS[j])) > -1);
         if(stringContainsIgnoreCase(ActionItem, _ACTION_LANGUAGE_ITEMS[j]))
         {
//            Print("ActionItem: ", ActionItem, " _ACTION_LANGUAGE_ITEMS[j]: ", _ACTION_LANGUAGE_ITEMS[j]);
//if action keyword found, cut it from the result action text
            result = StringTrimLeft(StringTrimRight(StringSubstr(ActionItem, stringFindIgnoreCase(ActionItem, _ACTION_LANGUAGE_COMMANDS[j]) + StringLen(_ACTION_LANGUAGE_COMMANDS[j]) + 1)));
//if after action keyword follows one of these letters, cut it also - it is a kind of delimiter for better readibility
            if(
               StringFind(result, ":") == 0 || 
               StringFind(result, "-") == 0
            )
            result = StringSubstr(result, 1);
         }
      }
      
//   Print("ParseActionText: ", ActionItem, ", |", result, "|");
   return(result);
}

//------------------------------------------------------------------
// TradeAllowed function return true if trading is possible         
//------------------------------------------------------------------
bool TradeAllowed(int MAXORDERS)
{
//Trade only once on each bar
   if(!IsTradeAllowed()) 
      return(false);
   if(OrdersTotal() >= MAXORDERS)
      return(false);
   return(true);
}
//------------------------------------------------------------------
int getOrdersTotalByMagicnumber(int MAGICNUMBER)
{
   int i = 0, OrdersTotalByMagicnumber = 0;
   for(i = 0; i < OrdersTotal(); i++)
   {
      OrderSelect(i, SELECT_BY_POS);
      if(OrderMagicNumber() == MAGICNUMBER)
         OrdersTotalByMagicnumber++;
   }
   return(OrdersTotalByMagicnumber);
}
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
// MM Modul                                                         
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
double GetLots(int MM_STRATEGY, int AMOUNT)
{
   double lot, result;

   switch(MM_STRATEGY)
   {
      case _MM_FIX_LOT:
      {
         lot = AMOUNT;

         break;
      }
      case _MM_FIX_PERC:
      {
         lot = NormalizeDouble(AccountFreeMargin() * AMOUNT / 1000.0, 1);

         break;
      }
      case _MM_FIX_PERC_AVG_LAST_PROFIT:
      {
         lot = NormalizeDouble(AccountFreeMargin() * AMOUNT / 1000.0, 1);

         break;
      }
   }

//   if(lot > AccountFreeMargin() / 1500.0)
//      lot = MathFloor(10 * AccountFreeMargin() / 1500.0)/ 10;

   if(lot < _MINLOTS)
      lot = _MINLOTS;
   else if(lot > _MAXLOTS)
      lot = _MAXLOTS;
      
   return(lot);
}
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
// Order management modul
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------

//------------------------------------------------------------------------------------
// Opens position according to arguments (short || long, amount of Lots to trade 
//------------------------------------------------------------------------------------
int OpenPosition(bool SHORTLONG, double LOTS, double STOPLOSS, double TAKEPROFIT, int SLIPPAGE, int MAGICNUMBER)
{
   if(SHORTLONG)
   {
      if(STOPLOSS > 0)
      if(Ask + _MIN_STOPLOSS_DISTANCE*Point < STOPLOSS)
      {
         Print("Bad OrderOpen() STOPLOSS defined. Price Bid was: ", Ask, " and STOPLOSS was: ", STOPLOSS, " . STOPLOSS set to minimal value: ", Bid + _MIN_STOPLOSS_DISTANCE*Point);
         STOPLOSS = Ask + _MIN_STOPLOSS_DISTANCE*Point;
      }
      if(TAKEPROFIT > 0)
      if(Bid - _MIN_TAKEPROFIT_DISTANCE*Point > TAKEPROFIT)
      {
         Print("Bad OrderOpen() TAKEPROFIT defined. Price Bid was: ", Bid, " and TAKEPROFIT was: ", TAKEPROFIT, " . TAKEPROFIT set to minimal value: ", Bid - _MIN_TAKEPROFIT_DISTANCE*Point);
         TAKEPROFIT = Bid - _MIN_TAKEPROFIT_DISTANCE*Point;
      }
      return(OrderSend(Symbol(), OP_SELL, LOTS, Bid, SLIPPAGE, STOPLOSS, TAKEPROFIT, "", MAGICNUMBER, 0, Red));
   }
   else
   {
      if(STOPLOSS > 0)
      if(Bid - _MIN_STOPLOSS_DISTANCE*Point < STOPLOSS)
      {
         Print("Bad OrderOpen() STOPLOSS defined. Price Bid was: ", Bid, " and STOPLOSS was: ", STOPLOSS, " . STOPLOSS set to minimal value: ", Bid - _MIN_STOPLOSS_DISTANCE*Point);
         STOPLOSS = Bid - _MIN_STOPLOSS_DISTANCE*Point;
      }
      if(TAKEPROFIT > 0)
      if(Ask + _MIN_TAKEPROFIT_DISTANCE*Point > TAKEPROFIT)
      {
         Print("Bad OrderOpen() TAKEPROFIT defined. Price Bid was: ", Ask, " and TAKEPROFIT was: ", TAKEPROFIT, " . TAKEPROFIT set to minimal value: ", Bid + _MIN_TAKEPROFIT_DISTANCE*Point);
         TAKEPROFIT = Ask + _MIN_TAKEPROFIT_DISTANCE*Point;
      }
      return(OrderSend(Symbol(), OP_BUY, LOTS, Ask, SLIPPAGE, STOPLOSS, TAKEPROFIT, "", MAGICNUMBER, 0, Blue));
   }
}
//------------------------------------------------------------------------------------
// Opens pending position according to arguments (sell stop || buy stop, amount of Lots to trade 
//------------------------------------------------------------------------------------
void OpenPendingPosition(bool SHORTLONG, double LOTS, double OPENPRICE, double STOPLOSS, double TAKEPROFIT, int SLIPPAGE, int MAGICNUMBER, datetime EXPIRATION)
{
   if(SHORTLONG)
   {
      OrderSend(Symbol(), OP_SELLSTOP, LOTS, OPENPRICE, SLIPPAGE, STOPLOSS, TAKEPROFIT, NULL, MAGICNUMBER, EXPIRATION, Red);
   }
   else
   {
      OrderSend(Symbol(), OP_BUYSTOP, LOTS, OPENPRICE, SLIPPAGE, STOPLOSS, TAKEPROFIT, NULL, MAGICNUMBER, EXPIRATION, Blue);
   }
}
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
//Position controll modul
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------

//------------------------------------------------------------------
void ModifyAllPositions(int MAGICNUMBER, double STOPLOSS, double TAKEPROFIT)
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
         break;
      if(OrderMagicNumber() != MAGICNUMBER)
         continue;
      
      ModifyPosition(OrderTicket(), STOPLOSS, TAKEPROFIT);
   }
}
//------------------------------------------------------------------------------------
void ModifyPosition(int TICKETNUMBER, double STOPLOSS, double TAKEPROFIT)
{
   STOPLOSS = NormalizeDouble(STOPLOSS, 4);
   TAKEPROFIT = NormalizeDouble(TAKEPROFIT, 4);
   
   OrderSelect(TICKETNUMBER, SELECT_BY_TICKET);
   if(NormalizeDouble(OrderStopLoss(), 4) == NormalizeDouble(STOPLOSS, 4) && NormalizeDouble(OrderTakeProfit(), 4) == NormalizeDouble(TAKEPROFIT, 4))
      return;

//check minimal distance of STOPLOSS and TAKEPROFIT and if are not met - correct SL and TP values to minimal values and print message into LOG file
   if(OrderType() == OP_BUY)
   {
      if(STOPLOSS > 0)
      if(Bid - _MIN_STOPLOSS_DISTANCE*Point < STOPLOSS)
      {
         Print("Bad OrderModify() STOPLOSS defined for order ticket: ", OrderTicket(), " and Magic number: ", OrderMagicNumber(), " . Price Bid was: ", Bid, " and STOPLOSS was: ", STOPLOSS, " . STOPLOSS set to minimal value: ", Bid - _MIN_STOPLOSS_DISTANCE*Point);
         STOPLOSS = Bid - _MIN_STOPLOSS_DISTANCE*Point;
      }
      if(TAKEPROFIT > 0)
      if(Ask + _MIN_TAKEPROFIT_DISTANCE*Point > TAKEPROFIT)
      {
         Print("Bad OrderModify() TAKEPROFIT defined for order ticket: ", OrderTicket(), " and Magic number: ", OrderMagicNumber(), " . Price Bid was: ", Ask, " and TAKEPROFIT was: ", TAKEPROFIT, " . TAKEPROFIT set to minimal value: ", Bid + _MIN_TAKEPROFIT_DISTANCE*Point);
         TAKEPROFIT = Ask + _MIN_TAKEPROFIT_DISTANCE*Point;
      }
      
      if(STOPLOSS > 0)
      if(OrderStopLoss() >= STOPLOSS)
         STOPLOSS = OrderStopLoss();
//      if(OrderTakeProfit() <= TAKEPROFIT)
//         TAKEPROFIT = OrderStopLoss();
   }
   if(OrderType() == OP_SELL)
   {
      if(STOPLOSS > 0)
      if(Ask + _MIN_STOPLOSS_DISTANCE*Point > STOPLOSS)
      {
         Print("Bad OrderModify() STOPLOSS defined for order ticket: ", OrderTicket(), " and Magic number: ", OrderMagicNumber(), " . Price Ask was: ", Ask, " and STOPLOSS was: ", STOPLOSS, " . STOPLOSS set to minimal value: ", Ask + _MIN_STOPLOSS_DISTANCE*Point);
         STOPLOSS = Ask + _MIN_STOPLOSS_DISTANCE*Point;
      }
      if(TAKEPROFIT > 0)
      if(Bid - _MIN_TAKEPROFIT_DISTANCE*Point < TAKEPROFIT)
      {
         Print("Bad OrderModify() TAKEPROFIT defined for order ticket: ", OrderTicket(), " and Magic number: ", OrderMagicNumber(), " . Price Ask was: ", Bid, " and TAKEPROFIT was: ", TAKEPROFIT, " . TAKEPROFIT set to minimal value: ", Ask - _MIN_TAKEPROFIT_DISTANCE*Point);
         TAKEPROFIT = Bid - _MIN_TAKEPROFIT_DISTANCE*Point;
      }

      if(STOPLOSS > 0)
      if(OrderStopLoss() <= STOPLOSS)
         return;
//      if(OrderTakeProfit() >= TAKEPROFIT)
//         TAKEPROFIT = OrderStopLoss();
   }
   
//   Print(Ask, " - ", Bid, " - ", OrderTicket(), " - ", OrderOpenPrice(), " - ", OrderStopLoss(), " - ", OrderTakeProfit(), " - ", STOPLOSS, " - ", TAKEPROFIT, " - ", OrderMagicNumber());
   OrderModify(OrderTicket(), OrderOpenPrice(), STOPLOSS, TAKEPROFIT, 0);
}
//------------------------------------------------------------------------------------
// Close all positions
//------------------------------------------------------------------------------------
int CloseAllPositions(int MAGICNUMBER)
{
   int i;
   int OrderTickets2Close[];
   ArrayResize(OrderTickets2Close, 0);
   
   for(i = 0; i < OrdersTotal(); i++)
   {
      OrderSelect(i, SELECT_BY_POS);
      if(OrderMagicNumber() != MAGICNUMBER)
         continue;
      ArrayResize(OrderTickets2Close, ArraySize(OrderTickets2Close) + 1);
      OrderTickets2Close[ArraySize(OrderTickets2Close)] = OrderTicket();
   }

   return(ClosePositions(OrderTickets2Close));
}
//------------------------------------------------------------------------------------
// Close all long positions
//------------------------------------------------------------------------------------
int CloseAllLongPositions(int MAGICNUMBER)
{
   int i;
   int OrderTickets2Close[];
   ArrayResize(OrderTickets2Close, 0);
   
   for(i = 0; i < OrdersTotal(); i++)
   {
      OrderSelect(i, SELECT_BY_POS);
      if(OrderMagicNumber() != MAGICNUMBER || OrderType() != OP_BUY)
         continue;
      ArrayResize(OrderTickets2Close, ArraySize(OrderTickets2Close) + 1);
      OrderTickets2Close[ArraySize(OrderTickets2Close) - 1] = OrderTicket();
   }

   return(ClosePositions(OrderTickets2Close));
}
//------------------------------------------------------------------------------------
// Close all short positions
//------------------------------------------------------------------------------------
int CloseAllShortPositions(int MAGICNUMBER)
{
   int i;
   int OrderTickets2Close[];
   ArrayResize(OrderTickets2Close, 0);
   
   for(i = 0; i < OrdersTotal(); i++)
   {
      OrderSelect(i, SELECT_BY_POS);
      if(OrderMagicNumber() != MAGICNUMBER || OrderType() != OP_SELL)
         continue;
      ArrayResize(OrderTickets2Close, ArraySize(OrderTickets2Close) + 1);
      OrderTickets2Close[ArraySize(OrderTickets2Close) - 1] = OrderTicket();
   }

   return(ClosePositions(OrderTickets2Close));
}
//------------------------------------------------------------------------------------
// Close positions by ticket array
//------------------------------------------------------------------------------------
int ClosePositions(int OrderTickets2Close[])
{
   int i, closed = 0;
   
   for(i = 0; i < ArraySize(OrderTickets2Close); i++)
   {
      closed += ClosePosition(OrderTickets2Close[i]);
   }
   
   return(closed);
}
//------------------------------------------------------------------------------------
// Close position by ticket
//------------------------------------------------------------------------------------
int ClosePosition(int OrderTicket2Close)
{
   int result = 0;
   
   if(OrderSelect(OrderTicket2Close, SELECT_BY_TICKET))
   {
      if(OrderType() == OP_SELL)
      {
         if(OrderClose(OrderTicket(), OrderLots(), Ask, 3, Orange))
            result = 1;
      }
      else if(OrderType() == OP_BUY)
      {
         if(OrderClose(OrderTicket(), OrderLots(), Bid, 3, Orange))
            result = 1;
      }
   }
   
   Print("Closed position: ", OrderTicket2Close, ", result: ", result);
   
   if(result == 0)
      ErrorCheckup();
   
   return(result);
}
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------
// Tools - rozne
//------------------------------------------------------------------
//------------------------------------------------------------------
//------------------------------------------------------------------

//------------------------------------------------------------------
bool SendPredefinedRecipientMail(string SUBJECT, string TEXT, string ATTACHMENT_PATH = "", string ATTACHMENT_TITLE = "")
{
   return(MailNotification (_MAIL_NOTIFICATION_TO, SUBJECT, TEXT, ATTACHMENT_PATH, ATTACHMENT_TITLE));
}


//------------------------------------------------------------------
bool MailNotification(string TO, string SUBJECT = "", string TEXT = "", string ATTACHMENT_PATH = "", string ATTACHMENT_TITLE = "")
{
   bool result = false;
   
   int sent = gSendMail("default", TO, SUBJECT, TEXT, ATTACHMENT_PATH, ATTACHMENT_TITLE);
//   Print(sent);
   if(sent == 1)
   {
      result = true;
      Print("Mail sent to ", TO, ", Subject:", SUBJECT, ", Text: ", TEXT, ", Attachment title:", ATTACHMENT_TITLE, ", Attachment path: ", ATTACHMENT_PATH);
   }
   else
      ErrorCheckup();
   
   return(result);
}

//------------------------------------------------------------------
string MakeScreenShot()
{
   int X_SIZE = _SCREENSHOT_X_SIZE;
   int Y_SIZE = _SCREENSHOT_Y_SIZE;
   
   string ResultFileName = "";
   string FileName;
   
   string hours = DoubleToStr(TimeHour(TimeCurrent()), 0);
   string minutes = DoubleToStr(TimeMinute(TimeCurrent()), 0);
   string seconds = DoubleToStr(TimeSeconds(TimeCurrent()), 0);
   
   if(StringLen(hours) == 1)
      hours = StringConcatenate("0", hours);
   if(StringLen(minutes) == 1)
      minutes = StringConcatenate("0", minutes);
   if(StringLen(seconds) == 1)
      seconds = StringConcatenate("0", seconds);
   
   FileName = StringConcatenate(TimeToStr(TimeCurrent(), TIME_DATE), "_", hours, "-", minutes, "-", seconds, ".gif");
   
   if(WindowScreenShot(FileName, X_SIZE, Y_SIZE))
   {
      ResultFileName = FileName;
      Print("Screenshot taken and saved as ", ResultFileName);
   }   
   else
      ErrorCheckup();
   
   return(ResultFileName);
}

//------------------------------------------------------------------
void ErrorCheckup()
{
   int error = GetLastError();
   if(_SENT_MAIL_NOTIFI_ON_ERROR == 1)
   {
      SendPredefinedRecipientMail(StringConcatenate("Error number ", error, " occured!"), StringConcatenate(" Error number ", error, " occured! \nError description: ", ErrorDescription(error)));
   }
   Print(StringConcatenate("Error number ", error, " occured!"), StringConcatenate(" Error number ", error, " occured! \nError description: ", ErrorDescription(error)));
}

//------------------------------------------------------------------
void DebugStringArray(string arr[])
{
   for(int i = 0; i < ArraySize(arr); i++)
      Print(i, ":", arr[i]);
}
//------------------------------------------------------------------
string UsedOrderIDs()
{
   string comment = "\nUsed ORDER IDs:\nMAGIC NUMBER - TICKET NUMBER\n";
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      OrderSelect(i, SELECT_BY_POS);
      comment = StringConcatenate(comment, OrderMagicNumber(), " - ", OrderTicket(), "\n");
   }
   
   return(comment);
}
//------------------------------------------------------------------
int ParseOrderIdFromActionString(string ParsedAction[])
{
   int OrderID;
   string parsedtext = "";
   
//determine ORDER_ID of processed action, if there is any defined
//if there is Order ID deined in action string - it has to be an integer value otherwise cancel action and return error
   if(ContainsAction(ParsedAction, ORDER_ID, parsedtext))
   {
      if(StrToInteger(parsedtext) > 0)
         OrderID = StrToInteger(parsedtext);
      else
      {
         Print("Error converting Order ID");
         return(0);
      }
   }

   return(OrderID);
//   UsedOrderIDsInfo = StringConcatenate(UsedOrderIDsInfo, "\n", OrderID);
}