
//document.onclick=function(ev){
//    var oEvent=ev||event;
//    var oLeft=oEvent.clientX+'px';
//    var oTop=oEvent.clientY+'px'
//    alert(oLeft+','+oTop)
//}

var voiceArray = new Array();
var str = "";

function javacalljstest(mm, nn)
{
	showProgressMm(mm, nn, 0);
	//scrolltopos(500, 500);
}

function javacallmovetotop()
{
	window.scrollTo(0 , 0);
}


function scrolltopos(x, y)
{
	window.scrollTo(x,y);
}

function changeColor(iColor, str1)
{
	var elem=document.getElementById(str1);
	if(iColor == 0)
		elem.style.fill="rgb(25,204,25)"; 
	else if(iColor == 1)
		elem.style.fill="rgb(255,0,0)"; 
	else if(iColor == 2)
		elem.style.fill="rgb(0,0,0)";
}

var strMode = "";
function setJSMode(str)
{
	strMode = str;
	window.showTapButton = str;
}

function hideProgressMM() {
    var elem=document.getElementById('progressBar');
    elem.width.baseVal.value=0;
    elem.height.baseVal.value=0;
}


var posx = 5000;

function showProgressMm(mm,nn,percent) {
    var meas=meas_pos[mm-meas_start];
    var pos=meas.pos;
    var notes=meas.notes;
    var w=pos.w;
    var x=notes[nn];//+w*percent;
    if(nn<notes.length-1){
        x+=(notes[nn+1]-x)*percent;
    }else{
        x+=(pos.x+w-x)*percent;
    }
    var elem=document.getElementById('progressBar');
    elem.x.baseVal.value=x;
    elem.y.baseVal.value=pos.y;
    elem.width.baseVal.value=4;
    elem.height.baseVal.value=pos.h;
    elem.style.fill="rgb(153,205,248)";
    
//    var elem2=document.getElementById('1_1_0');
//    //elem2.setAttributeNS (null, 'fill','rgb(25,204,25)');
//    elem2.style.fill="rgb(25,204,25)";
    
    if(posx > x)
    {
    	window.scrollTo(0, pos.y - 35);
    }
    else
    {
    	posx = x;
    }
}

function showProgressBar(x,y,w,h) {
    var elem=document.getElementById('progressBar');
    elem.setAttributeNS (null, 'x',x);
    elem.setAttributeNS (null, 'y',y);
    elem.setAttributeNS (null, 'width',w);
    elem.setAttributeNS (null, 'height',h);
    elem.setAttributeNS (null, 'style',"fill:rgb(153,205,248)");
}


function highlightMeasure(from,to) {
    for (var i = meas_start+meas_pos.length-1; i >= 0; i--) {
        var elem=document.getElementById('m'+i);
        if (to>from && i>=from && i<to) {
            console.log(elem);
            elem.style.fill="rgba(220, 220, 220, 0.4)";
        }else{
            elem.style.fill="rgba(0, 0, 0, 0)";
        }
    };
}

function informApp(msg){
    document.location=msg;
}

var hiddenPopviewTimer = null;
var mstart = 0;
var mend = 0;

function clickMm(mm) {
    var ev=event || window.event;
    //highlightMeasure(mm);
    var x=ev.offsetX;
    var y=ev.offsetY;
    var pos = meas_pos[mm - meas_start].pos;
    var notes=meas_pos[mm - meas_start].notes;
    var num=notes.length;
    var nn=0;
    if (num>0 && x>=notes[0]) {
        for (; nn < num; nn++) {
            if (nn==num-1) {
                break;
            }else if (x>=notes[nn] && x<notes[nn+1]) {
                break;
            }
        };
    }
    //document.location="?clickmm="+mm+"&nn="+nn;
    //informApp("?clickmm="+mm+"&nn="+nn);
    window.loactiondemo.clickOnAndroid("clickmm="+mm+"&nn="+nn);
    showProgressMm(mm,nn,0);
    
    //if(window.showTapButton==="comment") 
    if(strMode === "comment")
    {
        var popview=document.getElementById("addcomment");
        if(!popview) {
            //var xmlns = 'http://www.w3.org/2000/svg';
            popview=document.createElement("div");
            document.body.appendChild (popview);
            popview.setAttributeNS (null, 'style','border:none; width:280px;position:absolute;visibility:visible;background:none');
            popview.setAttributeNS (null, 'id','addcomment');
        }
        popview.style.visibility="visible";
        if(pos.x>1024-280) {
            popview.style.left=pos.x+pos.w-280;
        }else{
            popview.style.left=pos.x;
        }
        popview.style.top=pos.y-20;
        popview.value=mm;
        var loopA=document.getElementById("commentA");
        if(!loopA){
            //var xmlns = 'http://www.w3.org/2000/svg';
            loopA=document.createElement("button");
            popview.appendChild (loopA);
            loopA.setAttributeNS (null, 'style','width:130px;height:30px;backgrounFEFBEBd:#;color:#27ae60;font-size:medium');
            loopA.setAttributeNS (null, 'id','commentA');
            data = document.createTextNode('添加点评');
            loopA.appendChild(data);
        }
        loopA.onclick=function(){
            // alert(mm+" "+pos.x+" "+pos.y+" "+pos.h);
            // informApp("?commenta="+mm+"&nn="+nn);
            window.loactiondemo.clickOnAndroid("?commenta="+mm+"&nn="+nn);
            clearTimeout(hiddenPopviewTimer);
            popview.style.visibility='hidden';
        }
        if (hiddenPopviewTimer) {
            clearTimeout(hiddenPopviewTimer);
        };
        hiddenPopviewTimer = setTimeout("addcomment.style.visibility='hidden';", 6000);
        return;
    }
    //if(window.showTapButton==="loopab") 
    if(strMode === "loopab")
    {
	    var popview=document.getElementById("popview");
	    popview.style.visibility="visible";
	    popview.style.left=pos.x;
	    popview.style.top=pos.y-20;
	    popview.value=mm;
	    var loopA=document.getElementById("loopA");
	    loopA.onclick=function(){
	        // alert(mm+" "+pos.x+" "+pos.y+" "+pos.h);
	        showLoopCursor(popview, true,pos.x-20,pos.y,pos.h);
	        //informApp("?loopa="+mm);
	        window.loactiondemo.clickOnAndroid("loopa="+mm);
	        mstart = mm;
	        highlightMeasure(mstart,mend);
	    }
	    loopB.onclick=function(){
	        showLoopCursor(popview, false,pos.x+pos.w+15,pos.y,pos.h);
	        // alert(mm);
	        //informApp("?loopb="+mm);
	        window.loactiondemo.clickOnAndroid("loopb="+mm);
	        mend = mm + 1;
	        highlightMeasure(mstart,mend);
	    }
	    if (hiddenPopviewTimer) {
	        clearTimeout(hiddenPopviewTimer);
	    };
	    hiddenPopviewTimer = setTimeout("popview.style.visibility='hidden';", 6000);
    }
}
function showLoopCursor(popview, isStart,x,y,h) {
    var elem_id=(isStart)?'playloopA':'playloopB';
    var elem=document.getElementById(elem_id);
    elem.style.visibility='visible';
    elem.x.baseVal.value=x;
    elem.y.baseVal.value=y;
    elem.width.baseVal.value=10;
    elem.height.baseVal.value=h;
    elem.style.fill=(isStart)?'#27ae60':'#c0392b';
    //elem.style.fill="rgb(153,205,248)";
    
    clearTimeout(hiddenPopviewTimer);
    popview.style.visibility='hidden';
}
function cancelLoopAB() {
    //alert('cancelLoopAB');
    var elem=document.getElementById('playloopA');
    elem.style.visibility='hidden';
    elem=document.getElementById('playloopB');
    elem.style.visibility='hidden';
    //informApp("?loopc");
    window.loactiondemo.clickOnAndroid("loopc");
    
    var popview=document.getElementById("popview");
    clearTimeout(hiddenPopviewTimer);
    popview.style.visibility='hidden';
    highlightMeasure(0,0);
}

function removeAllTempNotes() {
    var c=document.getElementById('tempNoteGroup');
    c.parentNode.removeChild(c);
}

function addNote(index,x,y,style) {
    var elem=document.getElementById('tempNote'+index);
    if(elem==null){
        var xmlns = 'http://www.w3.org/2000/svg';
        var c=document.getElementById('svg');
        var noteGroup=document.createElementNS(xmlns, 'g');
        noteGroup.setAttributeNS(null, 'id','tempNoteGroup');
        c.appendChild(noteGroup);
        
        elem=document.createElementNS(xmlns, 'circle');
        noteGroup.appendChild (elem);
//        c.appendChild(elem);
        
        elem.setAttributeNS (null, 'id','tempNote'+index);
    }
    elem.setAttributeNS (null, 'cx',x);
    elem.setAttributeNS (null, 'cy',y);
    elem.setAttributeNS (null, 'r','5');
    elem.setAttributeNS (null, 'style',style);
}

function showMessage(text,x,y) {
    var elem=document.getElementById('score');
    if(elem==null){
        var xmlns = 'http://www.w3.org/2000/svg';
        var c=document.getElementById('svg');
        elem=document.createElementNS(xmlns, 'text');
        c.appendChild (elem);
        elem.setAttributeNS (null, 'id','score');
        elem.setAttributeNS (null, 'text-anchor','middle');
        elem.setAttributeNS (null, 'font-size','45');
        elem.setAttributeNS (null, 'style','fill:rgb(100,200,10);');
    }
    elem.setAttributeNS (null, 'x',x);
    elem.setAttributeNS (null, 'y',y);
    var data = elem.lastChild;
    if(data==null){
        data = document.createTextNode('tt');
        elem.appendChild(data);
    }
    data.textContent=text;
}

function showScore(totalScore,x, score_y) {
    var elem=document.getElementById('score');
    if(elem==null){
        var xmlns = 'http://www.w3.org/2000/svg';
        var c=document.getElementById('svg');
        elem=document.createElementNS(xmlns, 'text');
        c.appendChild (elem);
        elem.setAttributeNS (null, 'id','score');
        elem.setAttributeNS (null, 'text-anchor','middle');
        elem.setAttributeNS (null, 'font-size','45');
        elem.setAttributeNS (null, 'style','fill:rgb(100,200,10);');
    }
    elem.setAttributeNS (null, 'x',x);
    elem.setAttributeNS (null, 'y',score_y);
    var data = elem.lastChild;
    if(data==null){
        data = document.createTextNode('tt');
        elem.appendChild(data);
    }
    data.textContent=totalScore;
}

function removeScore() {
    var elem=document.getElementById('score');
    elem.parentNode.removeChild(elem);
}

function showtest()

{
	var test = document.getElementById('ttest');
	test.value = "fasdf";
}

// function showFlag(mm,nn,text) {
//     var elem=document.getElementById('flags_'+mm+"_"+nn);
//     if(elem==null){
//         var xmlns = 'http://www.w3.org/2000/svg';
//         var c=document.getElementById('svg');
//         var noteGroup=document.createElementNS(xmlns, 'g');
//         noteGroup.setAttributeNS(null, 'id','tempFlagsGroup');
//         c.appendChild(noteGroup);
        
//         elem=document.createElementNS(xmlns, 'circle');
//         noteGroup.appendChild (elem);
//         //        c.appendChild(elem);
        
//         elem.setAttributeNS (null, 'id','flags_'+mm+"_"+nn);
//         elem.setAttributeNS (null, 'style',"fill:rgba(200, 100, 100, 0.8)");
//     }
//     var notes=meas_pos[mm].notes;
//     y=meas_pos[mm].pos.y-40;
//     x=notes[nn];
    
//     elem.setAttributeNS (null, 'cx',x);
//     elem.setAttributeNS (null, 'cy',y);
//     elem.setAttributeNS (null, 'r','10');
// }

function showFlag(mm,nn,text) {
    var elem=document.getElementById('flags_'+mm+"_"+nn);
    if(elem==null){
        var xmlns = 'http://www.w3.org/2000/svg';
        var c=document.getElementById('svg');
        var noteGroup=document.createElementNS(xmlns, 'g');
        noteGroup.setAttributeNS(null, 'id','tempFlagsGroup');
        c.appendChild(noteGroup);
        
        elem=document.createElementNS(xmlns, 'circle');
        noteGroup.appendChild (elem);
        //        c.appendChild(elem);
        
        elem.setAttributeNS (null, 'id','flags_'+mm+"_"+nn);
    }
    elem.setAttributeNS (null, 'style',"fill:rgba(200, 100, 100, 0.8)");
    var notes=meas_pos[mm].notes;
    y=meas_pos[mm].pos.y-35;
    x=notes[nn];
    
    elem.setAttributeNS (null, 'cx',x);
    elem.setAttributeNS (null, 'cy',y);
    elem.setAttributeNS (null, 'r','10');
    
    text = text.replace(/kongge/ig, " ");
    text = text.replace(/huanhang/ig, "\n");
    
    elem.onclick=function(){
        showCommentMessage(text,mm,nn);
    }
}

function showCommentMessage(text,mm,nn) {
    var notes=meas_pos[mm].notes;
    y=meas_pos[mm].pos.y-50;
    x=notes[nn];
    var elem=document.getElementById('score' + mm + "_" + nn);
    if(elem==null){
        var xmlns = 'http://www.w3.org/2000/svg';
        var c=document.getElementById('svg');
        elem=document.createElementNS(xmlns, 'text');
        c.appendChild (elem);
        elem.setAttributeNS (null, 'id','score' + mm + "_" + nn);
        elem.setAttributeNS (null, 'text-anchor','middle');
        elem.setAttributeNS (null, 'font-size','20');
        elem.setAttributeNS (null, 'style','fill:rgb(0,0,0);');
        elem.setAttributeNS (null, 'x',x);
    elem.setAttributeNS (null, 'y',y);
    }
    
    var data = elem.lastChild;
    if(data==null){
        data = document.createTextNode('tt');
        elem.appendChild(data);
        data.textContent=text;
    }else{
        elem.removeChild(data);
    }
}



function showVoiceFlag(mm,nn,voiceMessage) {
    var elem=document.getElementById('flags_'+mm+"_"+nn);
    //window.loactiondemo.clickOnAndroid('flags_'+mm+"_"+nn);
    //window.loactiondemo.clickOnAndroid("showVoiceFlag");
    if(elem==null){
        var xmlns = 'http://www.w3.org/2000/svg';
        var c=document.getElementById('svg');
        var noteGroup=document.createElementNS(xmlns, 'g');
        noteGroup.setAttributeNS(null, 'id','tempFlagsGroup');
        c.appendChild(noteGroup);
        
        elem=document.createElementNS(xmlns, 'circle');
        noteGroup.appendChild (elem);
        //        c.appendChild(elem);
        
        elem.setAttributeNS (null, 'id','flags_'+mm+"_"+nn);
    }
    elem.setAttributeNS (null, 'style',"fill:rgba(127, 255, 212, 0.8)");
    var notes=meas_pos[mm].notes;
    y=meas_pos[mm].pos.y-40;
    x=notes[nn];
    
    elem.setAttributeNS (null, 'cx',x);
    elem.setAttributeNS (null, 'cy',y);
    elem.setAttributeNS (null, 'r','10');
    
    //voice elem
    var voice=document.getElementById('audioPlay_'+mm+"_"+nn);
    if(voice==null){
        var c=document.getElementById('tempFlagsGroup');
        voice=document.createElement('audio');
        c.appendChild (voice);
        voice.setAttribute('id','audioPlay_'+mm+"_"+nn);
        voice.setAttribute('type', 'audio/mp3');
    }
    str = 'audioPlay_'+mm+"_"+nn;
    //window.loactiondemo.clickOnAndroid(str);
    if(voiceArray == undefined)
        voiceArray = new Array();
    voiceArray.push(str);
    //window.loactiondemo.clickOnAndroid(voiceArray.length);
    voice.setAttribute('src',voiceMessage);
    
    elem.onclick=function(){
        var voice=document.getElementById('audioPlay_'+mm+"_"+nn);
        //window.loactiondemo.clickOnAndroid(voiceArray.length);
        for(var i = 0; i < voiceArray.length; i ++)
        {

            var strtemp = voiceArray[i];
            //window.loactiondemo.clickOnAndroid(strtemp);
            var voice2 = document.getElementById(strtemp);
            if(!voice2.paused)
            {
                voice2.currentTime = 0;
                voice2.pause();
            }
        }
        voice.play();
}}

function closeAllvoice()
{
    for(var i = 0; i < voiceArray.length; i ++)
    {

        var strtemp = voiceArray[i];
        //window.loactiondemo.clickOnAndroid(strtemp);
        var voice2 = document.getElementById(strtemp);
        if(!voice2.paused)
        {
            voice2.currentTime = 0;
            voice2.pause();
        }
    }
}

//function showLineProgressBar(height) {
//    var elem=document.getElementById('lineprogress');
//    if(elem==null){
//        var xmlns = 'http://www.w3.org/2000/svg';
//        var c=document.getElementById('body');
//        elem=document.createElementNS(xmlns, 'div');
//        c.appendChild (elem);
//        elem.setAttributeNS (null, 'id','lineprogress');
////        elem.setAttributeNS (null, 'x',1024-22);
////        elem.setAttributeNS (null, 'y',0);
////        elem.setAttributeNS (null, 'width',20);
////        elem.setAttributeNS (null, 'style','fill:rgba(100,200,10,0.5);position:fixed; right:4;top:4;width:20px;height:900px;');
//        elem.setAttributeNS (null, 'style','background:#fff;position:fixed; right:2px;top:2px;width:20px;height:300px;border:1px solid red;');
//    }
////    elem.setAttributeNS (null, 'height',height);
//    
//}
