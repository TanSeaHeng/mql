//+------------------------------------------------------------------+
//|                                     Multi Time Signalling EA.mq4 |
//|                                 yright 2020, CrazyFxTrader Corp. |
//|                                         http://crazyfxtrader.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, CrazyFxTrader Corp."
#property link      "http://crazyfxtrader.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#include <stdlib.mqh>
#include <Canvas\Canvas.mqh>

#define WEB_TIMEOUT        5000
#define ERR_HTTP_ERROR_FIRST        ERR_USER_ERROR_FIRST+1000 //+511

datetime ExpiredTime = D'2020.03.10 00:00:00'; // Expired Date
int      AccountNo = 0;               // Account Number

enum ENUM_TRADING_TYPE {
   M1AndM5, // M1 & M5
   M5AndM15, // M5 & M15
   M15AndM30, // M15 & M30
   M30AndH1, // M30 & H1
   H1AndH4, // H1 & H4
   H4AndD1, // H4 & D1
};
enum ENUM_TAKEPROFIT_TYPE {
   FixPips,
   FixProfits,
};

enum ENUM_STOPLOSS_TYPE {
   SFixPips, // FixPips
   LowestOrHighest,
};


enum ENUM_TREND_IDENTITY {
   S0, // 0
   S1, // 1
   S2, // 2
   S3, // 3
   S4, // 4
   S5  // 5
};

enum ENUM_TRADING_STYLE {
   Trend,
   Swing
};

enum ENUM_EA_START_STOP
{
   DeleteAndStop, // Delete All Oders and Stop
   StartAgain // Start Again
};

input string P_Trading = "---------- General Trading Section ----------";
input bool TradingEnable = true; // Activate Auto Trading
input ENUM_TREND_IDENTITY TrendIdent = S1; // Trend Identifier
input double Lots = 0.01; // Fix Lot Size
input int MaxConTrades = 2; // Max Orders on One Pair
input int MaxTrades = 5; // Max Concurrent Orders on All Pairs
input bool ActiveMaxProfit = true; // Activate Close by MaxProfit;
input double MaxProfit = 100; // MaxProfit in USD
input bool ActiveMinProfit = true; // Activate Close by MinProfit;
input double MinProfit = -100; // MinProfit in USD
input ENUM_EA_START_STOP StartOrStop = StartAgain; // Start or Stop
input int MagicNumber = 5455665;
input string CommentOrder = "Multi Time Trading EA";
input ENUM_TRADING_STYLE TradingStyle = Swing; // Trading Type

input string P_FirstSystem = "---------- First Trading Section ----------";
input bool FirstTradingEnable = true; // Activate First Trading
input ENUM_TRADING_TYPE FirstTradingType = M1AndM5;
input ENUM_TAKEPROFIT_TYPE FirstTakeProfitType = FixPips; // TakeProfit Type
input double FirstTakeProfit = 50; // TP in Pips or USD Profit Per Trade
input ENUM_STOPLOSS_TYPE FirstStopLossType = LowestOrHighest;
input int FirstStopLoss = 7; // Pre Bar's Count or Pips for SL
input ENUM_TIMEFRAMES FirstTimeFrameForSL = PERIOD_M5; // TimeFrame For SL
input int FirstFirstMinCount = 10; // First TF Min Counters
input int FirstFirstMaxCount = 15; // First TF Max Counters
input int FirstSecondMinCount = 1; // Second TF Min Counters
input int FirstSecondMaxCount = 2; // Second TF Max Counters

input string P_SecondSystem = "---------- Second Trading Section ----------";
input bool SecondTradingEnable = true; // Activate Second Trading
input ENUM_TRADING_TYPE SecondTradingType = M5AndM15;
input ENUM_TAKEPROFIT_TYPE SecondTakeProfitType = FixPips; // TakeProfit Type
input double SecondTakeProfit = 50; // TP in Pips or USD Profit Per Trade
input ENUM_STOPLOSS_TYPE SecondStopLossType = LowestOrHighest;
input int SecondStopLoss = 7; // Pre Bar's Count or Pips for SL
input ENUM_TIMEFRAMES SecondTimeFrameForSL = PERIOD_M15; // TimeFrame For SL
input int SecondFirstMinCount = 4; // First TF Min Counters
input int SecondFirstMaxCount = 10; // First TF Max Counters
input int SecondSecondMinCount = 1; // Second TF Min Counters
input int SecondSecondMaxCount = 2; // Second TF Max Counters


input string P_ThirdSystem = "---------- Third Trading Section ----------";
input bool ThirdTradingEnable = true; // Activate Third Trading
input ENUM_TRADING_TYPE ThirdTradingType = M15AndM30;
input ENUM_TAKEPROFIT_TYPE ThirdTakeProfitType = FixPips; // TakeProfit Type
input double ThirdTakeProfit = 50; // TP in Pips or USD Profit Per Trade
input ENUM_STOPLOSS_TYPE ThirdStopLossType = LowestOrHighest;
input int ThirdStopLoss = 7; // Pre Bar's Count or Pips for SL
input ENUM_TIMEFRAMES ThirdTimeFrameForSL = PERIOD_M30; // TimeFrame For SL
input int ThirdFirstMinCount = 3; // First TF Min Counters
input int ThirdFirstMaxCount = 5; // First TF Max Counters
input int ThirdSecondMinCount = 1; // Second TF Min Counters
input int ThirdSecondMaxCount = 2; // Second TF Max Counters


input string P_TraingFilter = "---------- Trailing Section ----------";
input bool   UseTrailStop     = false;          // Activate Trail Stop
input bool   UseCloseByM1     = false;          // Activate Close By M1 Timeframe
input double InpTrailingStart = 20;             // Trailing Start in Pips
input double InpTrailingStop  = 20;            // Trailing Distance in Pips
input double InpTrailingStep  = 10;             // Trailing Step in Pips

input string P_TimeFilter = "---------- Time Filter Section ----------";
input bool TimeFilter = true; // Activate Time Filter
input string TradeStartTime = "3:00"; // GMT TradingStartTime
input string TradeStopTime = "9:00"; // GMT TradingEndTime


input string P_Symbols = "---------- Symbols Section ----------";
input bool MultiSymbols = true; // Activate Multi Symbols
input string Symbols = "GBPUSD, USDCHF, USDJPY, AUDUSD, NZDUSD, USDCAD, EURCHF, EURGBP, EURJPY, GBPJPY,EURUSD";

input string P_MA = "---------- MA Section ----------";
input ENUM_APPLIED_PRICE MA_Price = PRICE_CLOSE;
input ENUM_MA_METHOD MA_Method = MODE_EMA;
input int SmallMA_Period = 5;
input int BigMA_Period = 8;
input int BiggestMA_Period = 11;

input string P_GeneralAlert = "---------- General Alert Section ----------";
input int FirstAlertSames = 2; // First Alert Sames Box
input int SecondAlertSames = 3; // Second Alert Sames Box

input string P_Screen = "---------- Screen Section ----------";
input bool ScreenEnable = true; // Activate Screen Alert
color FirstUpTrendColor = ARGB(250, 0, 220, 0); // Up Trend Color
color FirstDownTrendColor = ARGB(255, 255, 0, 0); // Down Trend Color
color SecondUpTrendColor = ARGB(250, 0, 125, 255); // Up Trend Color
color SecondDownTrendColor = ARGB(255, 200, 100, 0); // Down Trend Color
color NoSignalColor = ARGB(255, 128, 128, 128); // No Signal Color
color BlinkUpTrendColor = ARGB(250, 0, 0, 0); // Up Trend Color
color BlinkDownTrendColor = ARGB(250, 0, 0, 0); // Up Trend Color
color FontColor = ARGB(255, 0, 0, 0); // Font Color
input int FontSize = 20; // Font Size
input string Font = "Arial"; // Font

input string P_Alert = "---------- Alert Section ----------";
bool inAlert = false; // Activate Popup alerts
bool inPush = false; // Activate Push-notifications
bool inMail = false; // Activate Mails
input bool inSound = false; // Activate Sound alert
input string FirstSoundName = "alert.wav"; // First Sound file
input string SecondSoundName = "alert.wav"; // Second Sound file

input string P_DataFrame = "---------- Dat Frame Section ----------";
input bool DataEnable = false; // Activate DataFrame Send
input string WebServer = "http://fxs.yu-huangdi.com/testurl.php"; // WebServer url

int refresh = 5;
int MaxBars = 500;
int Slippage = 10;

enum ENUM_TREND {
   NO_SIGNAL,
   UP_TREND,
   DOWN_TREND
};

struct MA_SIGNAL {
   string SymName;
   ENUM_TIMEFRAMES TimeFrame;
   ENUM_TREND Trend;
   int Counter;
   bool Trading;
   double Small;
   double Medium;
   double Big;
   
   void Reset()
   {
      Trend = NO_SIGNAL;
      Counter = 0;
      Trading = false;
      Small = 0;
      Medium = 0;
      Big = 0;
   }
   
   void Set(string sym="", ENUM_TIMEFRAMES tf=0)
   {
      if (sym == "") SymName = Symbol();
      else SymName = sym;
      if (tf == 0) TimeFrame = (ENUM_TIMEFRAMES)Period();
      else TimeFrame = tf;
      Reset();
   }
   
   void Signal(ENUM_TREND trend, double small=0, double medium=0, double big=0)
   {
      Small = small;
      Medium = medium;
      Big = big;
      if (trend == NO_SIGNAL)
      {
         Reset();
         return;
      }
      if (Trend == trend)
         Counter++;
      if (Trend != trend)
      {
         Reset();
         Trend = trend;
         Counter++;
      }
   }
};

MA_SIGNAL MaSignals[];

string SymbolList[];

ENUM_TIMEFRAMES TimeFrames[] = {PERIOD_M1,
      PERIOD_M5,
      PERIOD_M15,
      PERIOD_M30,
      PERIOD_H1,
      PERIOD_H4,
      PERIOD_D1};

struct NEW_BAR {
   datetime SavedTime;
   string SymName;
   ENUM_TIMEFRAMES TimeFrame;
   
   void Initialize(string sym="", ENUM_TIMEFRAMES tf=0)
   {
      if (sym == "") SymName = Symbol();
      else SymName = sym;
      if (tf == 0) TimeFrame = (ENUM_TIMEFRAMES)Period();
      else TimeFrame = tf;
      SavedTime = 0;
   }
   bool GetStatus(int shift=1)
   {
      datetime curTime=iTime(SymName, TimeFrame, shift);      
      if (curTime>SavedTime) {
         SavedTime=curTime;
         Print("   ***   New Bar opened. SymBol: " + SymName + ", TimeFrame: " + TimeFrameToString(TimeFrame));
         return(true);
      }
      else return(false);
   }
};

NEW_BAR NewBars[];

CCanvas MainCanvas, UpTrendCanvas, DownTrendCanvas;
int 
   _Y = 80,
   _Y_TREND = 30,
   _X_POS = 5,
   _Y_POS = 87,
   _X_PERIOD = 50,
   _Y_PERIOD = 30,
   _X_START = 5,
   _Y_START = 5,
   _X_TEXT_START = 15,
   _Y_TEXT_COUNT_START = 3,
   _Y_TEXT_TIME_START = 55,
   _Y_TEXT_TREND_START = 15,
   _TREND_WIDHT = 9;
   

int Blink = 0;
int RefreshSeconds = 1;
int RefreshSoundAndJson = 60;
datetime LastSendTime = 0;
bool MaxPofitReached = false;
bool MinPofitReached = false;

int OnInit()
{
   //if (CheckExpired()) return INIT_FAILED;
   if (CheckAccount() == false) return INIT_FAILED;
   
   Blink = 0;
   if (MultiSymbols)
   {
      string symbols;
      if (StringFind(Symbols, Symbol()) < 0)
         symbols = Symbols + "," + Symbol();
      else symbols = Symbols;
      //StringToUpper(symbols);
      getAvailableCurrencyPairs(SymbolList, symbols);
   }
   else 
   {
      ArrayResize(SymbolList, 1);
      SymbolList[0] = Symbol();
   }
   
   PreEngine(MaxBars);
   Engine();
   EventSetTimer(RefreshSeconds);
   if (ActiveMaxProfit)
   {
      if (StartOrStop == StartAgain) 
      {
         MaxPofitReached = false;
      }
      else 
      {
         CloseAllOrders();
         MaxPofitReached = true;
      }
   }
   if (ActiveMinProfit)
   {
      if (StartOrStop == StartAgain) 
      {
         MinPofitReached = false;
      }
      else 
      {
         CloseAllOrders();
         MinPofitReached = true; 
      }
   }
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   MainCanvas.Destroy();
   DownTrendCanvas.Destroy();
   UpTrendCanvas.Destroy();
   
   ObjectDelete(0, "MainCanvas");
   ObjectDelete(0, "DownTrendCanvas");
   ObjectDelete(0, "UpTrendCanvas");
   EventKillTimer();
   ArrayFree(MaSignals);
   //ArrayFree(TimeFrames);
   ArrayFree(NewBars);
   ArrayFree(SymbolList);
   Comment("");
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (!TradingEnable) return;
   if (IsNewDayBar()) 
   {
      MaxPofitReached = false;
      MinPofitReached = false;
   }
   CloseAllOrdersByMaxProfit();
   CloseAllOrdersByMinProfit();
   if (MaxPofitReached) return;
   if (MinPofitReached) return;
   TrailStop(InpTrailingStop, InpTrailingStep, InpTrailingStart);
   CheckOrder();
   EntryOrders();
}
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   Engine();
}
//+------------------------------------------------------------------+


bool CheckExpired()
{
   if (ExpiredTime < TimeCurrent())
   {
      Alert("Your account was already Expired.");
      return true;
   }
   return false;
}

bool CheckAccount()
{
   if (AccountNo == 0) return true;
   if (AccountInfoInteger(ACCOUNT_LOGIN) != AccountNo) 
   {
      Alert("Your account was not Registered.");
      return false;
   }
   return true;
}

bool IsNewDayBar()
{
   static datetime preDayTime = iTime(Symbol(), PERIOD_D1, 1);
   datetime curDayTime = iTime(Symbol(), PERIOD_D1, 0);
   if (preDayTime < curDayTime)
   {
      preDayTime = curDayTime;
      return true;
   }
   return false;
}

void MyAlert(string msg="", string soundName="")
{
   if (inAlert && msg != "") Alert(msg);
   else Print(msg);
      
   if (inPush && msg != "") SendNotification(msg);
   if (inMail && msg != "") SendMail(msg, msg);
   if (inSound) PlaySound(soundName);
}


int GetMaSignal(string sym = "", ENUM_TIMEFRAMES tf = 0)
{
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   if (sym == "") symbol = Symbol();
   else symbol = sym;
   if (tf == 0) timeframe = (ENUM_TIMEFRAMES)Period();
   else timeframe = tf;
   int size = ArraySize(MaSignals);
   for (int i = 0; i < size; i++)
   {
      if (MaSignals[i].SymName == symbol && MaSignals[i].TimeFrame == timeframe)
         return i;
   }
   MA_SIGNAL maSignal;
   maSignal.Set(symbol, timeframe);
   ArrayResize(MaSignals, size + 1);
   MaSignals[size] = maSignal;
   return size;
}

int CheckSignal(string sym = "", ENUM_TIMEFRAMES tf = 0, int shift=1)
{
   string symbol;
   if (sym == "") symbol = Symbol();
   else symbol = sym;
   ENUM_TIMEFRAMES timeframe;
   if (tf == 0) timeframe = (ENUM_TIMEFRAMES)Period();
   else timeframe = tf;
   int bar = GetNewBar(symbol, timeframe);
   int signal = GetMaSignal(symbol, timeframe);
   if (!NewBars[bar].GetStatus(shift)) return signal;
   
   double smallMA = iMA(symbol, timeframe, SmallMA_Period, 0, MA_Method, MA_Price, shift);
   double bigMA = iMA(symbol, timeframe, BigMA_Period, 0, MA_Method, MA_Price, shift);
   double biggestMA = iMA(symbol, timeframe, BiggestMA_Period, 0, MA_Method, MA_Price, shift);
   if (smallMA > bigMA && bigMA > biggestMA)
      MaSignals[signal].Signal(UP_TREND, smallMA, bigMA, biggestMA);
   else if (smallMA < bigMA && bigMA < biggestMA)
      MaSignals[signal].Signal(DOWN_TREND, smallMA, bigMA, biggestMA);
   else MaSignals[signal].Signal(NO_SIGNAL, smallMA, bigMA, biggestMA);
   return signal;
}


int getAvailableCurrencyPairs(string& availableCurrencyPairs[], string symbolText = "")
{
//---   
   bool selected = false;
   const int symbolsCount = SymbolsTotal(selected);
   int currencypairsCount;
   ArrayResize(availableCurrencyPairs, symbolsCount);
   int idxCurrencyPair = 0;
   string symbolList = symbolText + ",";
   
   for(int idxSymbol = 0; idxSymbol < symbolsCount; idxSymbol++)
   {      
      string symbol = SymbolName(idxSymbol, selected);
      if (StringLen(symbol) <= 1) continue;
      symbol = symbol + ",";
      int result = StringFind(symbolList, symbol);
      if (result == -1) continue;
      
      symbol = StringSubstr(symbol, 0, StringLen(symbol) - 1);
      //if(firstChar != "#" && StringLen(symbol) == 6)
      {        
         availableCurrencyPairs[idxCurrencyPair++] = symbol; 
      }
   }
   currencypairsCount = idxCurrencyPair;
   ArrayResize(availableCurrencyPairs, currencypairsCount);
   return currencypairsCount;
}

void Engine()
{
   MA_SIGNAL CurrentCharts[];
   string FirstUpTrends = "";
   string FirstDownTrends = "";
   string SecondUpTrends = "";
   string SecondDownTrends = "";
   //Blink = 0;
   int uptrend = 0;
   int downtrend = 0;
   int signal;
   for (int j = 0; j < ArraySize(SymbolList); j++)
   {
      uptrend = 0;
      downtrend = 0;
      ENUM_TREND preTrend = 0;
      int maxUptrend = 0;
      int maxDowntrend = 0;
      for (int i = 0; i < ArraySize(TimeFrames); i++)
      {
         signal = CheckSignal(SymbolList[j], TimeFrames[i]);
         if (SymbolList[j] == Symbol())
            AppendMaSignal(CurrentCharts, MaSignals[signal]);
         
         if (MaSignals[signal].Trend == UP_TREND)
         {
            if (preTrend != MaSignals[signal].Trend)
            {
               if (maxUptrend < uptrend) maxUptrend = uptrend;
               uptrend = 0;
            }
            uptrend++;
         }
         else if (MaSignals[signal].Trend == DOWN_TREND)
         {
            if (preTrend != MaSignals[signal].Trend)
            {
               if (maxDowntrend < downtrend) maxDowntrend = downtrend;
               downtrend = 0;
            }
            downtrend++;
         }
         preTrend = MaSignals[signal].Trend;
      }
      if (maxDowntrend > downtrend) downtrend = maxDowntrend;
      if (maxUptrend > uptrend) uptrend = maxUptrend;
      
      if (FirstAlertSames > SecondAlertSames)
      {
         if (uptrend >= FirstAlertSames)
            FirstUpTrends += SymbolList[j] + ",";
         else if (uptrend >= SecondAlertSames)
            SecondUpTrends += SymbolList[j] + ",";
            
         if (downtrend >= FirstAlertSames)
            FirstDownTrends += SymbolList[j] + ",";
         else if (downtrend >= SecondAlertSames)
            SecondDownTrends += SymbolList[j] + ",";
      }
      else
      {
         if (uptrend >= SecondAlertSames)
            SecondUpTrends += SymbolList[j] + ",";
         else if (uptrend >= FirstAlertSames)
            FirstUpTrends += SymbolList[j] + ",";
         
         if (downtrend >= SecondAlertSames)
            SecondDownTrends += SymbolList[j] + ",";
         else if (downtrend >= FirstAlertSames)
            FirstDownTrends += SymbolList[j] + ",";
      }
   }
   if (StringLen(FirstUpTrends) > 0)
      FirstUpTrends = StringSubstr(FirstUpTrends, 0, StringLen(FirstUpTrends) - 1);
   if (StringLen(SecondUpTrends) > 0)
      SecondUpTrends = StringSubstr(SecondUpTrends, 0, StringLen(SecondUpTrends) - 1);
      
   if (StringLen(FirstDownTrends) > 0)
      FirstDownTrends = StringSubstr(FirstDownTrends, 0, StringLen(FirstDownTrends) - 1);
   if (StringLen(SecondDownTrends) > 0)
      SecondDownTrends = StringSubstr(SecondDownTrends, 0, StringLen(SecondDownTrends) - 1);
   
   DisplayCharts(CurrentCharts, FirstUpTrends, FirstDownTrends, SecondUpTrends, SecondDownTrends);
   if (ReFreshSoundJson())
   {
      SoundsAlert(CurrentCharts, FirstUpTrends, FirstDownTrends, SecondUpTrends, SecondDownTrends);
      SendJson(CurrentCharts, FirstUpTrends, FirstDownTrends, SecondUpTrends, SecondDownTrends);
   }
   ArrayFree(CurrentCharts);
}

void AppendMaSignal(MA_SIGNAL& maSignals[], MA_SIGNAL& maSignal)
{
   int size = ArraySize(maSignals);
   ArrayResize(maSignals, size + 1);
   maSignals[size] = maSignal;
}

string TimeFrameToString(int tf)
{
   switch(tf)
   {
      case PERIOD_M1: return("M1");
      case PERIOD_M5: return("M5");
      case PERIOD_M15: return("M15");
      case PERIOD_M30: return("M30");
      case PERIOD_H1: return("H1");
      case PERIOD_H4: return("H4");
      case PERIOD_D1: return("D1");
      case PERIOD_W1: return("W1");
      case PERIOD_MN1: return("MN1");
      default:return("Unknown timeframe");
   }
}

int GetNewBar(string sym="", ENUM_TIMEFRAMES tf=0)
{
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   if (sym == "") symbol = Symbol();
   else symbol = sym;
   if (tf == 0) timeframe = (ENUM_TIMEFRAMES)Period();
   else timeframe = tf;
   
   int size = ArraySize(NewBars);
   
   for (int i = 0; i < size; i++)
   {
      if (NewBars[i].SymName == symbol && NewBars[i].TimeFrame == timeframe)
         return i;
   }
   NEW_BAR newbar;
   newbar.Initialize(symbol, timeframe);
   ArrayResize(NewBars, size + 1);
   NewBars[size] = newbar;
   return size;
}


void DisplayCharts(MA_SIGNAL& maSignals[], string firstUpTrends, string firstDownTrends, string secondUpTrends, string secondDownTrends)
{
   if (!ScreenEnable) return;
   string upTrends= "";
   string downTrends = "";
   color firstUpColor;
   color firstDownColor;
   color secondUpColor;
   color secondDownColor;
   if (FirstAlertSames > SecondAlertSames)
   {
      firstUpColor = SecondUpTrendColor;
      firstDownColor = SecondDownTrendColor;
      secondUpColor = FirstUpTrendColor;
      secondDownColor = FirstDownTrendColor;
   }
   else
   {
      firstUpColor = FirstUpTrendColor;
      firstDownColor = FirstDownTrendColor;
      secondUpColor = SecondUpTrendColor;
      secondDownColor = SecondDownTrendColor;
   }
   if (Blink > 0)
   {
      Blink = 0;
      if (FirstAlertSames > SecondAlertSames)
      {
         firstUpColor = BlinkUpTrendColor;
         firstDownColor = BlinkDownTrendColor;
      }
      else
      {
         secondUpColor = BlinkUpTrendColor;
         secondDownColor = BlinkDownTrendColor;
      }
   }
   else
      Blink++;
   if (StringLen(firstUpTrends) <= 0)
   {
      upTrends = secondUpTrends;
   }
   else if (StringLen(secondUpTrends) <= 0)
      upTrends = firstUpTrends;
   else upTrends = firstUpTrends + "," + secondUpTrends;
   
   if (StringLen(firstDownTrends) <= 0)
   {
      downTrends = secondDownTrends;
   }
   else if (StringLen(secondDownTrends) <= 0)
      downTrends = firstDownTrends;
   else downTrends = firstDownTrends + "," + secondDownTrends;

   int upcounts = StringLen(upTrends);
   int downcounts = StringLen(downTrends);
   int maincounts = ArraySize(maSignals);
   int mainWidth = maincounts * _X_PERIOD;
   if (upcounts < downcounts) upcounts = downcounts;
   int trendWidth = upcounts * (FontSize - _TREND_WIDHT);
   
   if (trendWidth < mainWidth) trendWidth = mainWidth;
   
   if (ObjectFind("UpTrendCanvas")==-1) {
      UpTrendCanvas.CreateBitmapLabel("UpTrendCanvas",_X_POS,_Y_POS,trendWidth,_Y_TREND,COLOR_FORMAT_ARGB_NORMALIZE); 
      ObjectSetInteger(0,"UpTrendCanvas",OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
   UpTrendCanvas.Resize(trendWidth, _Y_TREND);
   UpTrendCanvas.Erase(ARGB(255,0,0,0));
   
   UpTrendCanvas.FillRectangle(0,0,trendWidth,_Y_TREND, FirstUpTrendColor);
   UpTrendCanvas.FillRectangle(1,1,trendWidth-1,_Y_TREND-1, ARGB(255,255,255,255));
   if (StringLen(firstUpTrends) <= 0)
   {
      UpTrendCanvas.FontSet(Font,FontSize, FW_BOLD ,0);
      UpTrendCanvas.TextOut(_X_START, _Y_TEXT_TREND_START, secondUpTrends, secondUpColor, TA_LEFT|TA_VCENTER);
   }
   else if (StringLen(secondUpTrends) <= 0)
   {
      UpTrendCanvas.FontSet(Font,FontSize, FW_BOLD ,0);
      UpTrendCanvas.TextOut(_X_START, _Y_TEXT_TREND_START, firstUpTrends, firstUpColor, TA_LEFT|TA_VCENTER);
   }
   else
   {
      UpTrendCanvas.FontSet(Font,FontSize, FW_BOLD ,0);
      UpTrendCanvas.TextOut(_X_START, _Y_TEXT_TREND_START, firstUpTrends + " ", firstUpColor, TA_LEFT|TA_VCENTER);
      UpTrendCanvas.FontSet(Font,FontSize, FW_BOLD ,0);
      UpTrendCanvas.TextOut(_X_START + (StringLen(firstUpTrends) + 1) * (FontSize - _TREND_WIDHT), _Y_TEXT_TREND_START, secondUpTrends, secondUpColor, TA_LEFT|TA_VCENTER);
   }
   UpTrendCanvas.Update();
   
   if (ObjectFind("MainCanvas")==-1) {
      MainCanvas.CreateBitmapLabel("MainCanvas",_X_POS,_Y_POS + _Y_TREND,mainWidth,_Y,COLOR_FORMAT_ARGB_NORMALIZE); 
      ObjectSetInteger(0,"MainCanvas",OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
   MainCanvas.Resize(mainWidth, _Y);
   MainCanvas.Erase(ARGB(255,0,0,0));
   
   MainCanvas.FillRectangle(0,0,mainWidth,_Y, ARGB(255,0,0,0));
   for (int i = 1; i < maincounts + 1; i++)
   {
      MainCanvas.LineVertical(_X_PERIOD * i, 0, _Y, ARGB(255,0,0,0));
      if (maSignals[i-1].Trend == UP_TREND)
      {
         MainCanvas.FillRectangle(_X_PERIOD * (i - 1) + 1, 1,  _X_PERIOD * i, _Y - 2, FirstUpTrendColor);
         MainCanvas.FontSet(Font,FontSize, FW_BOLD ,0);
         MainCanvas.TextOut(_X_PERIOD * (i - 1) + _X_TEXT_START, _Y_TEXT_COUNT_START, IntegerToString(maSignals[i-1].Counter), FontColor);
         MainCanvas.FontSet(Font,FontSize, FW_BOLD ,0);
         MainCanvas.TextOut(_X_PERIOD * (i - 1) + _X_TEXT_START, _Y_TEXT_TIME_START, TimeFrameToString(maSignals[i-1].TimeFrame), FontColor);
      }
      else if (maSignals[i-1].Trend == DOWN_TREND)
      {
         MainCanvas.FillRectangle(_X_PERIOD * (i - 1) + 1, 1,  _X_PERIOD * i, _Y - 2, FirstDownTrendColor);
         MainCanvas.FontSet(Font,FontSize, FW_BOLD ,0);
         MainCanvas.TextOut(_X_PERIOD * (i - 1) + _X_TEXT_START, _Y_TEXT_COUNT_START, IntegerToString(maSignals[i-1].Counter), FontColor);
         MainCanvas.FontSet(Font,FontSize, FW_BOLD ,0);
         MainCanvas.TextOut(_X_PERIOD * (i - 1) + _X_TEXT_START, _Y_TEXT_TIME_START, TimeFrameToString(maSignals[i-1].TimeFrame), FontColor);
      }
      else
      {
         MainCanvas.FillRectangle(_X_PERIOD * (i - 1) + 1, 1,  _X_PERIOD * i, _Y - 2, NoSignalColor);
         MainCanvas.FontSet(Font,FontSize, FW_BOLD ,0);
         MainCanvas.TextOut(_X_PERIOD * (i - 1) + _X_TEXT_START, _Y_TEXT_TIME_START, TimeFrameToString(maSignals[i-1].TimeFrame), FontColor);
      }
   }
   MainCanvas.Update();
      
   if (ObjectFind("DownTrendCanvas")==-1) {
      DownTrendCanvas.CreateBitmapLabel("DownTrendCanvas",_X_POS,_Y_POS + _Y_TREND + _Y, trendWidth,_Y_TREND,COLOR_FORMAT_ARGB_NORMALIZE);
      ObjectSetInteger(0,"DownTrendCanvas",OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
   DownTrendCanvas.Resize(trendWidth, _Y_TREND);
   DownTrendCanvas.Erase(ARGB(255,0,0,0));
   DownTrendCanvas.FillRectangle(0,0,trendWidth,_Y_TREND, FirstDownTrendColor);
   DownTrendCanvas.FillRectangle(1,1,trendWidth-1,_Y_TREND-2, ARGB(255,255,255,255));
   if (StringLen(firstDownTrends) <= 0)
   {
      DownTrendCanvas.FontSet(Font,FontSize, FW_BOLD ,0);
      DownTrendCanvas.TextOut(_X_START, _Y_TEXT_TREND_START, secondDownTrends, secondDownColor, TA_LEFT|TA_VCENTER);
   }
   else if (StringLen(secondDownTrends) <= 0)
   {
      DownTrendCanvas.FontSet(Font,FontSize, FW_BOLD ,0);
      DownTrendCanvas.TextOut(_X_START, _Y_TEXT_TREND_START, firstDownTrends, firstDownColor, TA_LEFT|TA_VCENTER);      
   }
   else
   {
      DownTrendCanvas.FontSet(Font,FontSize, FW_BOLD ,0);
      DownTrendCanvas.TextOut(_X_START, _Y_TEXT_TREND_START, firstDownTrends + " ", firstDownColor, TA_LEFT|TA_VCENTER);
      DownTrendCanvas.FontSet(Font,FontSize, FW_BOLD ,0);
      DownTrendCanvas.TextOut(_X_START + (StringLen(firstDownTrends) + 1) * (FontSize - _TREND_WIDHT), _Y_TEXT_TREND_START, secondDownTrends, secondDownColor, TA_LEFT|TA_VCENTER);
   }
   DownTrendCanvas.Update();
}

void SoundsAlert(MA_SIGNAL& maSignals[], string firstUpTrends, string firstDownTrends, string secondUpTrends, string secondDownTrends)
{
   if (!inSound) return;
   
   int uptrend = 0;
   int downtrend = 0;
   for (int i = 0; i < ArraySize(maSignals); i++)  
   {
      if (maSignals[i].Trend == UP_TREND)
         uptrend++;
      else if (maSignals[i].Trend == DOWN_TREND)
         downtrend++;
   }
   if (FirstAlertSames > SecondAlertSames)
   {
      if (uptrend >= FirstAlertSames || downtrend >= FirstAlertSames)
         MyAlert("", FirstSoundName);
      else if (uptrend >= SecondAlertSames || downtrend >= SecondAlertSames)
         MyAlert("", SecondSoundName);
   }
   else
   {
      if (uptrend >= SecondAlertSames || downtrend >= SecondAlertSames)
         MyAlert("", SecondSoundName);
      else if (uptrend >= FirstAlertSames || downtrend >= FirstAlertSames)
         MyAlert("", FirstSoundName);
   }
}

int SendJson(MA_SIGNAL& maSignals[], string firstUpTrends, string firstDownTrends, string secondUpTrends, string secondDownTrends)
{
   if (!DataEnable) return -1;
   Comment("");
   string json = BuildJson(maSignals, firstUpTrends, firstDownTrends, secondUpTrends, secondDownTrends);
   string out;
   //string url=StringFormat("%s/token:",WebServer,Token);
   string url=StringFormat("%s",WebServer);
   //string params=StringFormat("%s",UrlEncode(json));
   string params=StringFormat("%s",json);
   int code = PostRequest(out,url,params,WEB_TIMEOUT);
   if (code != 0)
      Comment("Send Json Error, Please check Web Server url!");
   else Comment("Sent Json to WebServer Url: " + WebServer);
   return code;
}

string BuildJson(MA_SIGNAL& maSignals[], string firstUpTrends, string firstDownTrends, string secondUpTrends, string secondDownTrends)
{
   //string result = "Timeframe: ";
   string result = "";
   string upTrends = "";
   string downTrends = "";
   if (firstUpTrends == "") upTrends = secondUpTrends;
   else if (secondUpTrends == "") upTrends = firstUpTrends;
   else upTrends = firstUpTrends + "," + secondUpTrends;
   if (firstDownTrends == "") downTrends = secondDownTrends;
   else if (secondDownTrends == "") downTrends = firstDownTrends;
   else downTrends = firstDownTrends + "," + secondDownTrends;
   
   //for (int i = 0; i < ArraySize(TimeFrames); i++)
   //{
   //   result += TimeFrameToString(TimeFrames[i]) + ", ";
   //}
   //if (ArraySize(TimeFrames) > 0)
   //   result = StringSubstr(result, 0, StringLen(result) - 2);
   //result += "\nSignal:           0=Gray, 1=Green, 2=Red";
   //result += "\nBars:             Counter of trend bar\n";
   //result += "\nJson";
   result += "{";
   result += "\n  \"time\": \"" + TimeToString(TimeCurrent()) + "\",";
   result += "\n  \"pair1\": \"" + upTrends + "\",";
   result += "\n  \"pair2\": \"" + downTrends + "\",";
   result += "\n  \"data\":[";
   for (int i = 0; i < ArraySize(TimeFrames); i++)
   {
      result += "\n     { \"Timeframe\": \"" + TimeFrameToString(TimeFrames[i]) + 
         "\",\"Signal\": " + IntegerToString(maSignals[i].Trend) + ",\"Bars\": " + IntegerToString(maSignals[i].Counter) + "},";
   }
   result = StringSubstr(result, 0, StringLen(result) - 1);
   result += "\n  ]";
   result += "\n}\n";
   return result;
}

string UrlEncode(const string text)
{
   string result=NULL;
   int length=StringLen(text);
   for(int i=0; i<length; i++)
   {
   ushort ch=StringGetCharacter(text,i);
   
   if((ch>=48 && ch<=57) || // 0-9
      (ch>=65 && ch<=90) || // A-Z
      (ch>=97 && ch<=122) || // a-z
      (ch=='!') || (ch=='\'') || (ch=='(') ||
      (ch==')') || (ch=='*') || (ch=='-') ||
      (ch=='.') || (ch=='_') || (ch=='~')
      )
     {
      result+=ShortToString(ch);
     }
   else
     {
      if(ch==' ')
         result+=ShortToString('+');
      else
        {
         uchar array[];
         int total=ShortToUtf8(ch,array);
         for(int k=0;k<total;k++)
            result+=StringFormat("%%%02X",array[k]);
        }
     }
   }
   return result;
}

//+------------------------------------------------------------------+
int ShortToUtf8(const ushort _ch,uchar &out[])
  {
   //---
   if(_ch<0x80)
     {
      ArrayResize(out,1);
      out[0]=(uchar)_ch;
      return(1);
     }
   //---
   if(_ch<0x800)
     {
      ArrayResize(out,2);
      out[0] = (uchar)((_ch >> 6)|0xC0);
      out[1] = (uchar)((_ch & 0x3F)|0x80);
      return(2);
     }
   //---
   if(_ch<0xFFFF)
     {
      if(_ch>=0xD800 && _ch<=0xDFFF)//Ill-formed
        {
         ArrayResize(out,1);
         out[0]=' ';
         return(1);
        }
      else if(_ch>=0xE000 && _ch<=0xF8FF)//Emoji
        {
         int ch=0x10000|_ch;
         ArrayResize(out,4);
         out[0] = (uchar)(0xF0 | (ch >> 18));
         out[1] = (uchar)(0x80 | ((ch >> 12) & 0x3F));
         out[2] = (uchar)(0x80 | ((ch >> 6) & 0x3F));
         out[3] = (uchar)(0x80 | ((ch & 0x3F)));
         return(4);
        }
      else
        {
         ArrayResize(out,3);
         out[0] = (uchar)((_ch>>12)|0xE0);
         out[1] = (uchar)(((_ch>>6)&0x3F)|0x80);
         out[2] = (uchar)((_ch&0x3F)|0x80);
         return(3);
        }
     }
   ArrayResize(out,3);
   out[0] = 0xEF;
   out[1] = 0xBF;
   out[2] = 0xBD;
   return(3);
  }
  
  
int PostRequest(string &out,
                   const string url,
                   const string params,
                   const int timeout=5000)
{
   char data[];
   int data_size=StringLen(params);
   StringToCharArray(params,data,0,data_size);
   
   uchar result[];
   string result_headers;
   
   //--- application/x-www-form-urlencoded
   int res=WebRequest("POST",url,NULL,NULL,timeout,data,data_size,result,result_headers);
   //Print("WebRequest ",res," ",CharArrayToString(result,0,WHOLE_ARRAY,CP_UTF8),"/",ArraySize(result));
   if(res==200)//OK
   {
   //--- delete BOM
   int start_index=0;
   int size=ArraySize(result);
   for(int i=0; i<fmin(size,8); i++)
     {
      if(result[i]==0xef || result[i]==0xbb || result[i]==0xbf)
         start_index=i+1;
      else
         break;
     }
   //---
   out=CharArrayToString(result,start_index,WHOLE_ARRAY,CP_UTF8);
   return(0);
   }
   else
   {
   if(res==-1)
     {
      return(_LastError);
     }
   else
     {
      //--- HTTP errors
      if(res>=100 && res<=511)
        {
         out=CharArrayToString(result,0,WHOLE_ARRAY,CP_UTF8);
         return(ERR_HTTP_ERROR_FIRST+res);
        }
      return(res);
     }
   }
   return(0);
}


void PreEngine(int bars)
{
   
   for (int m = 0; m < refresh; m++)
   {
      ArrayFree(MaSignals);
      ArrayFree(NewBars);
      for (int j = 0; j < ArraySize(SymbolList); j++)
      {
         for (int i = 0; i < ArraySize(TimeFrames); i++)
         {
            for (int k = bars; k > 1; k--)
            {
               CheckSignal(SymbolList[j], TimeFrames[i], k);
            }
         }
      }
      Sleep(1000);
   }
}

bool TimeFiltering()
{
   if (!TimeFilter) return true;
   datetime current = TimeGMT();
   string currstr = TimeToString(current, TIME_DATE);
   string startTime = currstr + " " + TradeStartTime;
   string stopTime = currstr + " " + TradeStopTime;
   datetime begin = StrToTime(startTime);
   datetime end = StrToTime(stopTime);
   if (begin >= end) begin = begin - 24 * 3600;
   bool EAActivated = (current>begin && current<end);  
   return EAActivated;
}


bool OpenNewOrder(string symbol, int OrdType, double lot, ENUM_STOPLOSS_TYPE slType, int sl,
                  ENUM_TIMEFRAMES slTf, ENUM_TAKEPROFIT_TYPE tpType, double tp)
{
   int OrderTicketNum;
   double PipSize = GetPipSize(symbol);
   double ask, bid;
   double d_sl=0, d_tp=0;
   ask = MarketInfo(symbol, MODE_ASK);
   bid = MarketInfo(symbol, MODE_BID);
   double stoploss, takeprofit;
   double lots = NormalizeLot(lot, false, symbol);
   int digits = (int)MarketInfo(symbol, MODE_DIGITS);
   bool isSuccess;
   if (OrdType == OP_BUY)
   {
      OrderTicketNum = OrderSend(symbol, OP_BUY, lots, ask, Slippage, 0, 0, CommentOrder, MagicNumber, 0, clrGreen);
      if (OrderTicketNum < 0) return false; //failed to enter order
      
      stoploss = GetStopLoss(symbol, OrdType, slTf, ask, PipSize, sl, slType);
      if (!UseTrailStop)
         takeprofit = GetTakeProfit(symbol, ask, lots, PipSize, OrdType, tp, tpType);
      else takeprofit = 0;
      
      if (stoploss != 0 || takeprofit != 0)
      {
         if (!OrderSelect(OrderTicketNum, SELECT_BY_TICKET)) return false;
         if (stoploss != 0)
         {
            d_sl=CorrectPrice(symbol,stoploss); d_sl=(d_sl>=bid)?CorrectPrice(symbol,bid-3.0*PipSize):d_sl; 
         }
         else d_sl = 0;
         if (takeprofit != 0)
         {
            d_tp=CorrectPrice(symbol,takeprofit);d_tp=(d_tp<=ask)?CorrectPrice(symbol,ask+3.0*PipSize):d_tp;
         }
         else d_tp = 0;
         //Alert("tp:" + d_tp + " takeprofit:" + takeprofit + " sl:" + d_sl + " stoploss:" + stoploss);
         isSuccess = OrderModify(OrderTicket(), OrderOpenPrice(), d_sl, d_tp, 0, clrGreen);
         if(!isSuccess) 
            Print("Error in OrderModify. Error code=",GetLastError()); 
         else 
            Print("Order modified successfully.");
      }
      //if (getme_result == 0)
      //   bot.SendMessage(InpChannelId, "a=buy c=" + symbol + " s=" + DoubleToString(stoploss, digits) +
      //                  " t=" + DoubleToString(takeprofit, digits) + " r=" + IntegerToString(TrailingStop) + " m="  + IntegerToString(OrderTicketNum));
   }
   else if (OrdType == OP_SELL)
   {
      OrderTicketNum = OrderSend(symbol, OP_SELL, lots, bid, Slippage, 0, 0, CommentOrder, MagicNumber, 0, clrRed);
      if (OrderTicketNum < 0) return false; //failed to enter order
      stoploss = GetStopLoss(symbol, OrdType, slTf, bid, PipSize, sl, slType);
      if (!UseTrailStop)
         takeprofit = GetTakeProfit(symbol, bid, lots, PipSize, OrdType, tp, tpType);
      else takeprofit = 0;
      
      if (stoploss != 0 || takeprofit != 0)
      {
         if (!OrderSelect(OrderTicketNum, SELECT_BY_TICKET)) return false;
         if (takeprofit != 0)
         {
            d_tp=CorrectPrice(symbol,takeprofit); d_tp=(d_tp>=bid)?CorrectPrice(symbol,bid-3.0*PipSize):d_tp;
         }
         else d_tp = 0;
         if (stoploss != 0)
         {
            d_sl=CorrectPrice(symbol,stoploss); d_sl=(d_sl<=ask)?CorrectPrice(symbol,ask+3.0*PipSize):d_sl; 
         }
         else d_sl = 0;
            
         //Alert("tp:" + d_tp + " takeprofit:" + takeprofit + " sl:" + d_sl + " stoploss:" + stoploss);
         isSuccess = OrderModify(OrderTicket(), OrderOpenPrice(), d_sl, d_tp, 0, clrRed);
         if(!isSuccess) 
            Print("Error in OrderModify. Error code=",GetLastError()); 
         else 
            Print("Order modified successfully."); 
      }
      //if (getme_result == 0)
      //   bot.SendMessage(InpChannelId, "a=sell c=" + symbol + " s=" + DoubleToString(stoploss, digits) +
      //                  " t=" + DoubleToString(takeprofit, digits) + " r=" + IntegerToString(TrailingStop) + " m="  + IntegerToString(OrderTicketNum));
   }
   return true;
}

double GetPipSize(string symbol)
{
   double PipSize = MarketInfo(symbol, MODE_POINT);
   int pairdigits = (int)MarketInfo(symbol, MODE_DIGITS);
   if(pairdigits == 3 || pairdigits == 5) PipSize = PipSize * 10.0;
   if (PipSize == 0) PipSize = 1;
   if (StringFind(symbol,"XAUUSD") >= 0) PipSize = PipSize * 100;
   return PipSize;
}

int GetOrdersCount(string symbol="", int orderType = -1)
{
   int orders = OrdersTotal();
   int result = 0;
   string sym;
   sym = symbol;
   for (int i = orders - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS) == false) continue;
      if (symbol == "") sym = OrderSymbol();
      if(OrderSymbol() != sym || OrderMagicNumber()!= MagicNumber) continue;
      if (orderType == -1)
         result++;
      else if (orderType == OrderType())
         result++;
   }
   return result;
}

double GetStopLoss(string symbol, int ot, ENUM_TIMEFRAMES tf, double op=0,
   double ps = 1, int fix=1, ENUM_STOPLOSS_TYPE st=0)
{
   int index;
   if (fix == 0) return 0;
   if (st == LowestOrHighest)
   {
      if (ot == OP_BUY)
      {
         index = iLowest(symbol, tf, MODE_LOW, fix, 0);
         return iLow(symbol, tf, index);
      }
      else if (ot == OP_SELL)
      {
         index = iHighest(symbol, tf, MODE_HIGH, fix, 0);
         return iHigh(symbol, tf, index);
      }
   }
   else if (st == SFixPips)
   {
      if (ot == OP_BUY)
         return op - fix * ps;
      else if (ot == OP_SELL)
         return op + fix * ps;
      else return 0;
   }
   return 0;
}

double GetTakeProfit(string symbol, double op, double ls, double ps, int ot, double fix, ENUM_TAKEPROFIT_TYPE tp)
{
   if (fix == 0) return 0;
   if (tp == FixPips)
   {
      if (ot == OP_BUY)
         return op + fix * ps;
      else if (ot == OP_SELL)
         return op - fix * ps;
      else return 0;
   }
   else if (tp == FixProfits)
   {
      double dLotSize = MarketInfo(symbol, MODE_LOTSIZE);
      double profitRate = CalcProfitRate(symbol);
      if (ot == OP_BUY)
         return op + fix / dLotSize / ls / profitRate;
      else if (ot == OP_SELL)
         return op - fix / dLotSize / ls / profitRate;
      else return 0;
   }
   else return 0;
   return 0;
}

void EntryOrders()
{
   if (!TimeFiltering()) return;   
   for (int i = 0; i < ArraySize(SymbolList); i++)
   {
      if (FirstTradingEnable)
         ActiveTradingSystem(i, FirstTradingType, FirstFirstMaxCount, FirstFirstMinCount, FirstSecondMaxCount, FirstSecondMinCount
                           , FirstStopLossType, FirstStopLoss, FirstTimeFrameForSL, FirstTakeProfitType, FirstTakeProfit);
      if (SecondTradingEnable)
         ActiveTradingSystem(i, SecondTradingType, SecondFirstMaxCount, SecondFirstMinCount, SecondSecondMaxCount, SecondSecondMinCount
                           , SecondStopLossType, SecondStopLoss, SecondTimeFrameForSL, SecondTakeProfitType, SecondTakeProfit);
      if (ThirdTradingEnable)
         ActiveTradingSystem(i, ThirdTradingType, ThirdFirstMaxCount, ThirdFirstMinCount, ThirdSecondMaxCount, ThirdSecondMinCount
                           , ThirdStopLossType, ThirdStopLoss, ThirdTimeFrameForSL, ThirdTakeProfitType, ThirdTakeProfit);
   }
}

bool PositionClose(int orderTicket, int slippage)
{
   if (!OrderSelect(orderTicket, SELECT_BY_TICKET)) return false;
   double bid = SymbolInfoDouble(OrderSymbol(), SYMBOL_BID);
   double ask = SymbolInfoDouble(OrderSymbol(), SYMBOL_ASK);
   bool isSuccess = false;
   if (OrderType() == OP_BUY)
   {
      isSuccess = OrderClose(OrderTicket(), OrderLots(), bid, slippage, clrGreen);
   }
   else if (OrderType() == OP_SELL)
   {
      isSuccess = OrderClose(OrderTicket(), OrderLots(), ask, slippage, clrRed);
   }
   return isSuccess;
}


//+------------------------------------------------------------------+
//| Trailing Stop function                                           |
//+------------------------------------------------------------------+
void TrailStop(double dist=20.0, double step=1.0, double start=0) {

   if (!UseTrailStop) return;
   
   double sl_new=0;
   double osl=0;
   double oop=0;
   
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == false) continue;
      if(OrderMagicNumber()!= MagicNumber) continue;
      double _bid = SymbolInfoDouble(OrderSymbol(), SYMBOL_BID);
      double _ask = SymbolInfoDouble(OrderSymbol(), SYMBOL_ASK);
      double pipSize = GetPipSize(OrderSymbol());
      int digits = (int)SymbolInfoInteger(OrderSymbol(), SYMBOL_DIGITS);

      osl=OrderStopLoss();
      oop=OrderOpenPrice();
      //if (osl == 0) continue;
      if(OrderType()==OP_BUY) {
         if (_bid > oop + start*pipSize) {
            if (_bid > osl + (dist+step)*pipSize) {
               sl_new=ND(_bid-dist*pipSize, digits);
               if (!OrderModify(OrderTicket(),OrderOpenPrice(),sl_new,OrderTakeProfit(),0,clrNONE)) {
                  Print("   ***   TS Order BUY Modify Error. OOP="+DTS(OrderOpenPrice(), digits)+", SL="+DTS(sl_new, digits)+
                        ", TP="+DTS(OrderTakeProfit(), digits));
               }
               else Print("   ***   TrailStop Order BUY Modify. Ticket#"+(string)OrderTicket()+" OrderOpenPrice="+DTS(OrderOpenPrice(), digits)+
                          ", SL="+DTS(sl_new, digits)+", TP="+DTS(OrderTakeProfit(), digits));
            }
         }
      }
      if(OrderType()==OP_SELL) {
         if (_ask < oop - start*pipSize) {
            if (_ask < osl - (dist+step)*pipSize || MathAbs(osl) < 1e-6) {
               sl_new=ND(_ask+dist*pipSize, digits);
               if (!OrderModify(OrderTicket(),OrderOpenPrice(),sl_new,OrderTakeProfit(),0,clrNONE)) {
                  Print("   ***   TS Order SELL Modify Error. OOP="+DTS(OrderOpenPrice(), digits)+", SL="+DTS(sl_new, digits)+
                        ", TP="+DTS(OrderTakeProfit(), digits));
               }
               else Print("   ***   TrailStop Order SELL Modify. Ticket#"+(string)OrderTicket()+" OrderOpenPrice="+DTS(OrderOpenPrice(), digits)+
                          ", SL="+DTS(sl_new, digits)+", TP="+DTS(OrderTakeProfit(), digits));
            }
         }
      }
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Normalize Double Custom function                                 |
//+------------------------------------------------------------------+
double ND(double v, int dg)  {
    return(NormalizeDouble(v,dg));
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Double to String Custom function                                 |
//+------------------------------------------------------------------+
string DTS(double value, int dg) {
  return(DoubleToString(value,dg));
}
//+------------------------------------------------------------------+

void CheckOrder()
{
   if (!UseTrailStop) return;
   if (!UseCloseByM1) return;
   
   for(int i=0; i<OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS) == false) continue;
      if(OrderMagicNumber()!= MagicNumber) continue;
      //if (OrderStopLoss() == 0) continue;
      if (OrderType() == OP_BUY)
      {
         if (OrderStopLoss() < OrderOpenPrice()) continue;
      }
      if (OrderType() == OP_SELL)
      {
         if (OrderStopLoss() > OrderOpenPrice()) continue;
      }
      int m1 = GetMaSignal(OrderSymbol(), PERIOD_M1);
      if (MaSignals[m1].Trend == NO_SIGNAL)
      {
         Print("OrderClosed By Grey Color, Ticket: " + IntegerToString(OrderTicket()) + 
               " Symbol: " + OrderSymbol() + " OrderType: " + OrderTypeToString(OrderType()));
         PositionClose(OrderTicket(), Slippage);
      }
      if (OrderType() == OP_BUY && MaSignals[m1].Trend == DOWN_TREND)
      {
         Print("OrderClosed By Opposite Color, Ticket: " + IntegerToString(OrderTicket()) + 
               " Symbol: " + OrderSymbol() + " OrderType: " + OrderTypeToString(OrderType()));
         PositionClose(OrderTicket(), Slippage);
      }
      if (OrderType() == OP_SELL && MaSignals[m1].Trend == UP_TREND)
      {
         Print("OrderClosed By Opposite Color, Ticket: " + IntegerToString(OrderTicket()) + 
               " Symbol: " + OrderSymbol() + " OrderType: " + OrderTypeToString(OrderType()));
         PositionClose(OrderTicket(), Slippage);
      }
   }
}


//+------------------------------------------------------------------+
//|  Normalize Lot Function                                          |
//+------------------------------------------------------------------+
double NormalizeLot(double lo, bool ro=false, string sy="") {
  double lot, k;
  if (sy=="" || sy=="0") sy=_Symbol;
  double ls=SymbolInfoDouble(sy, SYMBOL_VOLUME_STEP);
  double ml=SymbolInfoDouble(sy, SYMBOL_VOLUME_MIN);
  double mx=SymbolInfoDouble(sy, SYMBOL_VOLUME_MAX);

  if (ml==0) ml=0.1;
  if (mx==0) mx=100;

  if (ls>0) k=1/ls; else k=1/ml;
  if (ro) lot=MathCeil(lo*k)/k; 
  else    lot=MathFloor(lo*k)/k;

  if (lot<ml) lot=ml;
  if (lot>mx) lot=mx;

  return(lot);
}
//+------------------------------------------------------------------+

string OrderTypeToString(int ord)
{
   string result = "";
   switch (ord)
   {
      case OP_BUY:
         result = "OP_BUY";
         break;
      case OP_SELL:
         result = "OP_SELL";
         break;
      case OP_BUYLIMIT:
         result = "OP_BUYLIMIT";
         break;
      case OP_BUYSTOP:
         result = "OP_BUYSTOP";
         break;
      case OP_SELLLIMIT:
         result = "OP_SELLLIMIT";
         break;
      case OP_SELLSTOP:
         result = "OP_SELLSTOP";
         break;
      default:
         result = "None";
         break;
   }
   return result;
}


//+------------------------------------------------------------------+
//| Correct Price function                                           |
//+------------------------------------------------------------------+
double CorrectPrice (const string Symb, const double Price) {

  const double TickSize = MathMax(SymbolInfoDouble(Symb, SYMBOL_TRADE_TICK_SIZE), SymbolInfoDouble(Symb, SYMBOL_POINT));
  
  return(NormalizeDouble(((int)(Price / TickSize + 0.1)) * TickSize, (int)SymbolInfoInteger(Symb, SYMBOL_DIGITS)));
}
//+------------------------------------------------------------------+


double CalcProfitRate(string symbol)
{
   if (StringLen(symbol) != 6) return 1.0;
   string front = StringSubstr(symbol, 0, 3);
   string back = StringSubstr(symbol, 3, 3);
   double bid, ask;
   if (front == "USD")
   {
      bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      return 1.0 / ask;
   }
   else if (back == "USD")
      return 1.0;
   else
   {
      string newSymbol = back + "USD";
      string symbols[];
      int count = getAvailableCurrencyPairs(symbols, newSymbol);
      if (count == 1)
      {
         bid = SymbolInfoDouble(newSymbol, SYMBOL_BID);
         ask = SymbolInfoDouble(newSymbol, SYMBOL_ASK);
         return ask;
      }
      ArrayFree(symbols);
      newSymbol = "USD" + back;
      count = getAvailableCurrencyPairs(symbols, newSymbol);
      if (count == 1)
      {
         bid = SymbolInfoDouble(newSymbol, SYMBOL_BID);
         ask = SymbolInfoDouble(newSymbol, SYMBOL_ASK);
         return 1.0 / ask;
      }
   }
   return 1;
}

void ActiveTradingSystem(int i, ENUM_TRADING_TYPE TradingType, int FirstMaxCount, int FirstMinCount, int SecondMaxCount, 
                        int SecondMinCount, ENUM_STOPLOSS_TYPE slType, int sl, ENUM_TIMEFRAMES slTf, ENUM_TAKEPROFIT_TYPE tpType, 
                        double tp)
{
   
   int maxcount, mincount;
   int first, second;
   if (GetOrdersCount() >= MaxTrades) return;
   double high, low;
   switch (TradingType)
   {
      case M1AndM5:
         first = GetMaSignal(SymbolList[i], PERIOD_M1);
         second = GetMaSignal(SymbolList[i], PERIOD_M5);
         high = iHigh(SymbolList[i], PERIOD_M5, 1);
         low = iLow(SymbolList[i], PERIOD_M5, 1);
         break;
      case M5AndM15:
         first = GetMaSignal(SymbolList[i], PERIOD_M5);
         second = GetMaSignal(SymbolList[i], PERIOD_M15);
         high = iHigh(SymbolList[i], PERIOD_M15, 1);
         low = iLow(SymbolList[i], PERIOD_M15, 1);
         break;
      case M15AndM30:
         first = GetMaSignal(SymbolList[i], PERIOD_M15);
         second = GetMaSignal(SymbolList[i], PERIOD_M30);
         high = iHigh(SymbolList[i], PERIOD_M30, 1);
         low = iLow(SymbolList[i], PERIOD_M30, 1);
         break;
      case M30AndH1:
         first = GetMaSignal(SymbolList[i], PERIOD_M30);
         second = GetMaSignal(SymbolList[i], PERIOD_H1);
         high = iHigh(SymbolList[i], PERIOD_H1, 1);
         low = iLow(SymbolList[i], PERIOD_H1, 1);
         break;
      case H1AndH4:
         first = GetMaSignal(SymbolList[i], PERIOD_H1);
         second = GetMaSignal(SymbolList[i], PERIOD_H4);
         high = iHigh(SymbolList[i], PERIOD_H4, 1);
         low = iLow(SymbolList[i], PERIOD_H4, 1);
         break;
      case H4AndD1:
         first = GetMaSignal(SymbolList[i], PERIOD_H4);
         second = GetMaSignal(SymbolList[i], PERIOD_D1);
         high = iHigh(SymbolList[i], PERIOD_D1, 1);
         low = iLow(SymbolList[i], PERIOD_D1, 1);
         break;
      default:
         first = GetMaSignal(SymbolList[i], PERIOD_M1);
         second = GetMaSignal(SymbolList[i], PERIOD_M5);
         high = iHigh(SymbolList[i], PERIOD_M5, 1);
         low = iLow(SymbolList[i], PERIOD_M5, 1);
         break;
   }
   if (MaSignals[first].Trading == true) return;
   
   if (MaSignals[first].Trend == NO_SIGNAL || MaSignals[second].Trend == NO_SIGNAL)
      return;
   if (MaSignals[first].Trend != MaSignals[second].Trend) return;
   if (MaSignals[second].Counter < SecondMinCount || MaSignals[second].Counter > SecondMaxCount) return;
   if (FirstMaxCount == EMPTY_VALUE || FirstMaxCount == 0)
   {
      maxcount = SecondMaxCount;
      mincount = SecondMinCount;
   }
   else 
   {
      maxcount = FirstMaxCount;
      mincount = FirstMinCount;
   }
   if (MaSignals[first].Counter < mincount || MaSignals[first].Counter > maxcount) return;
   if (MaSignals[second].Small == 0 || MaSignals[second].Medium == 0 || MaSignals[second].Big == 0) return;
   
   if (high >= MaSignals[second].Small && low <= MaSignals[second].Small) return;
   if (high >= MaSignals[second].Medium && low <= MaSignals[second].Medium) return;
   if (high >= MaSignals[second].Big && low <= MaSignals[second].Big) return;
      
   if (MaSignals[first].Trend == UP_TREND)
   {
      bool trade = true;
      for (int k = 1; k <= TrendIdent; k++)
      {
         if (ArraySize(MaSignals) <= second + k) { trade = false; break;}
         if (MaSignals[second + k].SymName != SymbolList[i]) { trade = false; break;}
         if (MaSignals[second + k].Trend != UP_TREND) { trade = false; break;}
      }
      if (!trade) return;
      
      if (TradingStyle == Trend)
      {
         int trades = GetOrdersCount(SymbolList[i], OP_BUY);
         if (trades >= MaxConTrades) return;
         OpenNewOrder(SymbolList[i], OP_BUY, Lots, slType, sl, slTf, tpType, tp);
      }
      else 
      {
         int trades = GetOrdersCount(SymbolList[i], OP_SELL);
         if (trades >= MaxConTrades) return;
         OpenNewOrder(SymbolList[i], OP_SELL, Lots, slType, sl, slTf, tpType, tp);
      }
      MaSignals[first].Trading = true;
   }
   else if (MaSignals[first].Trend == DOWN_TREND)
   {
      
      bool trade = true;
      for (int k = 1; k <= TrendIdent; k++)
      {
         if (ArraySize(MaSignals) <= second + k) { trade = false; break;}
         if (MaSignals[second + k].SymName != SymbolList[i]) { trade = false; break;}
         if (MaSignals[second + k].Trend != DOWN_TREND) { trade = false; break;}
      }
      if (!trade) return;
      
      if (TradingStyle == Trend)
      {
         int trades = GetOrdersCount(SymbolList[i], OP_SELL);
         if (trades >= MaxConTrades) return;
         OpenNewOrder(SymbolList[i], OP_SELL, Lots, slType, sl, slTf, tpType, tp);
      }
      else 
      {
         int trades = GetOrdersCount(SymbolList[i], OP_BUY);
         if (trades >= MaxConTrades) return;
         OpenNewOrder(SymbolList[i], OP_BUY, Lots, slType, sl, slTf, tpType, tp);
      }
      MaSignals[first].Trading = true;
   }
}

bool ReFreshSoundJson()
{
   if (LastSendTime + RefreshSoundAndJson > TimeCurrent()) return false;
   LastSendTime = TimeCurrent();
   return true;
}


void CloseAllOrders()
{
   int size = OrdersTotal();
   for (int i = size - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS)) continue;
      if (OrderMagicNumber() != MagicNumber) continue;
      PositionClose(OrderTicket(), Slippage);
   }
}

void CloseAllOrdersByMaxProfit()
{
   if (!ActiveMaxProfit) return;
   double sum = 0;
   for(int i=0; i<OrdersTotal(); i++) 
   {
      if(OrderSelect(i, SELECT_BY_POS) == false) continue;
      if(OrderMagicNumber()!= MagicNumber) continue;
      sum += OrderProfit();
   }
   if (sum < MaxProfit) return;
   CloseAllOrders();
   MaxPofitReached = true;
}


void CloseAllOrdersByMinProfit()
{
   if (!ActiveMinProfit) return;
   double sum = 0;
   for(int i=0; i<OrdersTotal(); i++) 
   {
      if(OrderSelect(i, SELECT_BY_POS) == false) continue;
      if(OrderMagicNumber()!= MagicNumber) continue;
      sum += OrderProfit();
   }
   if (sum > MinProfit) return;
   CloseAllOrders();
   MinPofitReached = true;
}