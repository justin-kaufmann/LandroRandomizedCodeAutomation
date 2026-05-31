local frame =
CreateFrame(
"Frame",
"LLRCA_MainFrame",
UIParent,
"BasicFrameTemplateWithInset"
)

frame:SetSize(
--560,
--700
560,
760
)

frame:SetPoint(

LLRCA_DB.framePos.point,

UIParent,

LLRCA_DB.framePos.relativePoint,

LLRCA_DB.framePos.x,

LLRCA_DB.framePos.y

)

frame:Hide()

LLRCA_Frame = frame

local PAD=20

local WIDTH=

frame:GetWidth()

-
(
PAD*2
)

frame:SetMovable(
true
)

frame:EnableMouse(
true
)

frame:RegisterForDrag(
"LeftButton"
)

frame:SetScript(

"OnDragStart",

function(self)

self:StartMoving()

end

)

frame:SetScript(

"OnDragStop",

function(self)

self:StopMovingOrSizing()

local point,
_,
relativePoint,
x,
y=

self:GetPoint()

LLRCA_DB.framePos=
{

point=point,

relativePoint=relativePoint,

x=x,

y=y

}

end

)

----- TITLE

local title =
frame:CreateFontString(
nil,
"OVERLAY",
"GameFontNormalLarge"
)

title:SetPoint(
"TOP",
0,
-10
)

title:SetText(
"Landro Automated Random-Code-Generator"
)

---

-- CODE COUNT

local countLabel =
frame:CreateFontString(
nil,
"OVERLAY",
"GameFontNormal"
)

countLabel:SetPoint(
"TOPLEFT",
20,
-35
)

countLabel:SetText(

LLRCA_L.CODES

)

local countHelp=

frame:CreateFontString(
nil,
"OVERLAY",
"GameFontNormal"
)

countHelp:SetWidth(
360
)

countHelp:SetJustifyH(
"LEFT"
)

countHelp:SetPoint(
"TOPLEFT",
20,
-60
)

countHelp:SetText(

LLRCA_L.CODES_DESC

)

local box =
CreateFrame(
"EditBox",
nil,
frame,
"InputBoxTemplate"
)

box:SetSize(
WIDTH,
34
)

box:SetPoint(
"TOPLEFT",
20,
-82
)

box:SetNumeric(
true
)

box:SetNumber(
LLRCA_DB.codeCount
or
100
)

LLRCA_CountBox = box


---

-- GOSSIP PATH

local pathLabel=

frame:CreateFontString(
nil,
"OVERLAY",
"GameFontNormal"
)

pathLabel:SetPoint(
"TOPLEFT",
20,
-145
)

pathLabel:SetText(
LLRCA_L.PATH
)

local pathHelp=

frame:CreateFontString(
nil,
"OVERLAY",
"GameFontNormal"
)

pathHelp:SetWidth(
360
)

pathHelp:SetJustifyH(
"LEFT"
)

pathHelp:SetPoint(
"TOPLEFT",
20,
-170
)

pathHelp:SetText(

LLRCA_L.PATH_DESC

)

local function CreatePathBox(
y,
index
)

local label=

frame:CreateFontString(
nil,
"OVERLAY",
"GameFontNormal"
)

label:SetPoint(
"TOPLEFT",
20,
y+20
)

label:SetText(

LLRCA_L_LABLE_MENUPOINT
..
" "
..
index

)

local e=

CreateFrame(
"EditBox",
nil,
frame,
"InputBoxTemplate"
)

e:SetSize(
WIDTH,
34
)

e:SetPoint(
"TOPLEFT",
20,
y
)

e:SetAutoFocus(
false
)

e:SetText(

LLRCA_DB.path[index]
or
""

)

e:SetScript(

"OnTextChanged",

function(self)

LLRCA_DB.path[index]=

self:GetText()

end

)

return e

end

LLRCA_Path1=
CreatePathBox(
-240,
1
)

LLRCA_Path2=
CreatePathBox(
-315,
2
)

LLRCA_Path3=
CreatePathBox(
-390,
3
)

---

-- STATUS

local status =
frame:CreateFontString(
nil,
"OVERLAY",
"GameFontNormal"
)

status:SetWidth(
WIDTH-20
)

status:SetJustifyH(
"LEFT"
)

status:SetSpacing(
4
)

status:SetFont(

STANDARD_TEXT_FONT,

16,

"OUTLINE"

)

status:SetPoint(
"TOPLEFT",
20,
-455
)

status:SetText(
LLRCA_L.NOT_STARTED
)

LLRCA_Status = status

---

local reset=

CreateFrame(
"Button",
nil,
frame,
"UIPanelButtonTemplate"
)

reset:SetSize(
WIDTH,
30
)

reset:SetPoint(
"BOTTOMLEFT",
PAD,
70
)

reset:SetText(
LLRCA_L_DEFAULT
)

reset:SetScript(

"OnClick",

function()

LLRCA_DB.codeCount=
LLRCA_DEFAULTS.codeCount

LLRCA_CountBox:SetNumber(
LLRCA_DEFAULTS.codeCount
)

for i,v in ipairs(
LLRCA_DEFAULTS.path
)

do

LLRCA_DB.path[i]=v

end

LLRCA_Path1:SetText(
LLRCA_DB.path[1]
)

LLRCA_Path2:SetText(
LLRCA_DB.path[2]
)

LLRCA_Path3:SetText(
LLRCA_DB.path[3]
)

end

)

--------------------------------------------------
-- START BUTTON
--------------------------------------------------

local btn =
CreateFrame(
"Button",
nil,
frame,
"UIPanelButtonTemplate"
)

btn:SetSize(
WIDTH,
40
)

btn:SetPoint(
"BOTTOMLEFT",
PAD,
20
)

btn:SetText(
LLRCA_L.START
)

LLRCA_StartButton=
btn