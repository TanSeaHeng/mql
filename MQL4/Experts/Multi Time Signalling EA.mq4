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
input bool inSound = true; // Activate Sound alert
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
   
   void Reset()
   {
      Trend = NO_SIGNAL;
      Counter = 0;
      Trading = false;
   }
   
   void Set(string sym="", ENUM_TIMEFRAMES tf=0)
   {
      if (sym == "") SymName = Symbol();
      else SymName = sym;
      if (tf == 0) TimeFrame = (ENUM_TIMEFRAMES)Period();
      else TimeFrame = tf;
      Counter = 0;
      Trend = NO_SIGNAL;
      Trading = false;
   }
   
   void Signal(ENUM_TREND trend)
   {
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
      StringToUpper(symbols);
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
      MaSignals[signal].Signal(UP_TREND);
   else if (smallMA < bigMA && bigMA < biggestMA)
      MaSignals[signal].Signal(DOWN_TREND);
   else MaSignals[signal].Signal(NO_SIGNAL);
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

bool ReFreshSoundJson()
{
   if (LastSendTime + RefreshSoundAndJson > TimeCurrent()) return false;
   LastSendTime = TimeCurrent();
   return true;
}