.EDITOR_HTML <- "<!DOCTYPE html>
<html>
<head>
<meta charset=\"utf-8\">
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }

/* ── wrapper: scoped to avoid polluting Jamovi's outer body ── */
#sem-editor {
  font-family: -apple-system, BlinkMacSystemFont, sans-serif;
  font-size: 13px;
}

/* ── toolbar ─────────────────────────────────────────────── */
#toolbar {
  display: flex; align-items: center; gap: 6px;
  padding: 5px 8px; background: #f5f5f5;
  border-bottom: 1px solid #ddd;
}
.tool-btn {
  padding: 3px 10px; border: 1px solid #ccc; border-radius: 3px;
  background: #fff; cursor: pointer; font-size: 12px; white-space: nowrap;
  line-height: 1.5;
}
.tool-btn:hover { background: #e8e8e8; }
.tool-btn.active { background: #1976D2; color: #fff; border-color: #1976D2; }
.toggle-btn { border-style: dashed; }
.toggle-btn.active { border-style: solid; }

.spacer { flex: 1; }

/* ── canvas ──────────────────────────────────────────────── */
#canvas {
  display: block; width: 100%; height: 480px;
  background: #fafafa;
  background-image: radial-gradient(circle, #e0e0e0 1px, transparent 1px);
  background-size: 22px 22px;
  cursor: default;
}
#canvas.pending { cursor: crosshair; }

/* ── nodes ───────────────────────────────────────────────── */
.node-observed rect  { fill: #fff; stroke: #444; stroke-width: 1.5; }
.node-latent ellipse { fill: #f0f4ff; stroke: #555; stroke-width: 1.5; }
.node-selected rect,
.node-selected ellipse { stroke: #1976D2 !important; stroke-width: 2.5; }
.node-label {
  font-size: 12px; text-anchor: middle; dominant-baseline: central;
  pointer-events: none; user-select: none;
}

/* ── edges ───────────────────────────────────────────────── */
.edge-loading    { stroke: #555; stroke-width: 1.5; stroke-dasharray: 6,3; fill: none; }
.edge-regression { stroke: #555; stroke-width: 1.5; fill: none; }
.edge-covariance { stroke: #555; stroke-width: 1.5; fill: none; }
.edge-selected line, .edge-selected path { stroke: #1976D2 !important; stroke-width: 2.5; }
.edge-preview { stroke: #1976D2; stroke-width: 1.5; stroke-dasharray: 5,3; fill: none; pointer-events: none; }

/* ── estimate labels ─────────────────────────────────────── */
.est-lbl {
  font-size: 10px; fill: #c62828; text-anchor: middle;
  dominant-baseline: central; pointer-events: none;
}

/* ── error / disturbance nodes ───────────────────────────── */
.node-error circle { fill: #fff; stroke: #888; stroke-width: 1; }
.error-label { font-size: 10px; fill: #666; text-anchor: middle; dominant-baseline: central; pointer-events: none; }

/* ── constrained edges (fixed parameter) ─────────────────── */
.edge-constrained > line,
.edge-constrained > path { stroke: #1565C0; }

/* ── canvas hint ─────────────────────────────────────────── */
.canvas-hint { fill: #bbb; font-size: 13px; pointer-events: none; user-select: none; }

/* ── constraint label on edges ───────────────────────────── */
.constraint-lbl {
  font-size: 10px; fill: #1565C0; font-weight: bold; text-anchor: middle;
  dominant-baseline: central; pointer-events: none;
}

/* ── context menu ────────────────────────────────────────── */
.ctx-menu {
  position: fixed; background: #fff; border: 1px solid #ccc; border-radius: 5px;
  box-shadow: 0 3px 10px rgba(0,0,0,0.2); z-index: 100; min-width: 160px; overflow: hidden;
}
.ctx-menu.hidden { display: none; }
.ctx-item {
  padding: 7px 14px; cursor: pointer; font-size: 13px; white-space: nowrap;
}
.ctx-item:hover { background: #f0f0f0; }
.ctx-item.danger { color: #c62828; }
.ctx-sep { height: 1px; background: #eee; margin: 2px 0; }

/* ── rename modal ────────────────────────────────────────── */
#renameModal {
  position: fixed; inset: 0; background: rgba(0,0,0,0.25);
  z-index: 200; display: flex; align-items: center; justify-content: center;
}
#renameModal.hidden { display: none; }
.modal-box {
  background: #fff; padding: 18px 20px; border-radius: 6px; min-width: 250px;
  box-shadow: 0 4px 20px rgba(0,0,0,0.2);
}
.modal-title { font-weight: 600; margin-bottom: 10px; font-size: 13px; }
.modal-input {
  width: 100%; padding: 5px 7px; border: 1px solid #ccc; border-radius: 3px;
  font-size: 13px; outline: none;
}
.modal-input:focus { border-color: #1976D2; }
.modal-btns { display: flex; gap: 8px; justify-content: flex-end; margin-top: 12px; }
.modal-btn {
  padding: 4px 14px; border: 1px solid #ccc; border-radius: 3px;
  cursor: pointer; font-size: 13px; background: #fff;
}
.modal-btn:hover { background: #eee; }
.modal-btn.primary { background: #1976D2; color: #fff; border-color: #1976D2; }
.modal-btn.primary:hover { background: #1565C0; }
</style>
</head>
<body>

<div id=\"sem-editor\">

<!-- ── toolbar ─────────────────────────────────────────────── -->
<div id=\"toolbar\">
  <button id=\"btnEst\" class=\"tool-btn toggle-btn\">%%LABEL_SHOW_EST%%</button>
  <span class=\"spacer\"></span>
  <button id=\"btnLayout\" class=\"tool-btn\">%%LABEL_LAYOUT%%</button>
</div>

<!-- ── SVG canvas ──────────────────────────────────────────── -->
<svg id=\"canvas\" xmlns=\"http://www.w3.org/2000/svg\">
  <defs>
    <marker id=\"arr\" markerWidth=\"8\" markerHeight=\"8\" refX=\"6\" refY=\"3\" orient=\"auto\">
      <path d=\"M0,0 L0,6 L8,3 z\" fill=\"#555\"/>
    </marker>
    <marker id=\"arr-sel\" markerWidth=\"8\" markerHeight=\"8\" refX=\"6\" refY=\"3\" orient=\"auto\">
      <path d=\"M0,0 L0,6 L8,3 z\" fill=\"#1976D2\"/>
    </marker>
    <marker id=\"arr-s\" markerWidth=\"8\" markerHeight=\"8\" refX=\"2\" refY=\"3\" orient=\"auto-start-reverse\">
      <path d=\"M0,0 L0,6 L8,3 z\" fill=\"#555\"/>
    </marker>
    <marker id=\"arr-s-sel\" markerWidth=\"8\" markerHeight=\"8\" refX=\"2\" refY=\"3\" orient=\"auto-start-reverse\">
      <path d=\"M0,0 L0,6 L8,3 z\" fill=\"#1976D2\"/>
    </marker>
  </defs>
</svg>

</div><!-- /#sem-editor -->

<!-- ── context menu: node ──────────────────────────────────── -->
<div id=\"ctxNode\" class=\"ctx-menu hidden\">
  <div id=\"ctxAddLoading\" class=\"ctx-item\" data-action=\"addLoading\" style=\"display:none\">%%LABEL_ADD_LOADING%%</div>
  <div class=\"ctx-item\" data-action=\"addRegression\">%%LABEL_ADD_REGRESSION%%</div>
  <div class=\"ctx-item\" data-action=\"addCovariance\">%%LABEL_ADD_COVARIANCE%%</div>
</div>

<!-- ── context menu: edge ──────────────────────────────────── -->
<div id=\"ctxEdge\" class=\"ctx-menu hidden\">
  <div id=\"ctxFixValue\" class=\"ctx-item\" data-action=\"fixValue\">%%LABEL_FIX_VALUE%%</div>
  <div id=\"ctxRemoveConstraint\" class=\"ctx-item\" data-action=\"removeConstraint\" style=\"display:none\">%%LABEL_REMOVE_CONSTRAINT%%</div>
  <div class=\"ctx-sep\"></div>
  <div class=\"ctx-item danger\" data-action=\"deleteEdge\">%%LABEL_DELETE%%</div>
</div>

<!-- ── context menu: error node ──────────────────────────────── -->
<div id=\"ctxError\" class=\"ctx-menu hidden\">
  <div class=\"ctx-item\" data-action=\"errPosTop\">%%LABEL_ERR_TOP%%</div>
  <div class=\"ctx-item\" data-action=\"errPosBottom\">%%LABEL_ERR_BOTTOM%%</div>
  <div class=\"ctx-item\" data-action=\"errPosLeft\">%%LABEL_ERR_LEFT%%</div>
  <div class=\"ctx-item\" data-action=\"errPosRight\">%%LABEL_ERR_RIGHT%%</div>
  <div class=\"ctx-sep\"></div>
  <div class=\"ctx-item\" data-action=\"errCov\">%%LABEL_ADD_COVARIANCE%%</div>
</div>

<!-- ── rename modal ────────────────────────────────────────── -->
<div id=\"renameModal\" class=\"hidden\">
  <div class=\"modal-box\">
    <div class=\"modal-title\">%%LABEL_EDIT_NAME%%</div>
    <input id=\"renameInput\" class=\"modal-input\" type=\"text\">
    <div id=\"renameError\" style=\"color:#c62828;font-size:11px;margin-top:4px;display:none;\">%%LABEL_NAME_CONFLICT%%</div>
    <div class=\"modal-btns\">
      <button id=\"btnRenameCancel\" class=\"modal-btn\">%%LABEL_CANCEL%%</button>
      <button id=\"btnRenameOK\"     class=\"modal-btn primary\">%%LABEL_OK%%</button>
    </div>
  </div>
</div>

<!-- ── constraint popup (positioned near click) ────────────── -->
<div id=\"constraintPopup\" class=\"ctx-menu hidden\" style=\"padding:10px 12px;min-width:180px;\">
  <div style=\"font-size:12px;font-weight:600;margin-bottom:6px;\">%%LABEL_FIX_PARAM_TITLE%%</div>
  <input id=\"constraintInput\" class=\"modal-input\" type=\"text\" placeholder=\"0\" style=\"margin-bottom:4px;\">
  <div id=\"constraintError\" style=\"color:#c62828;font-size:11px;margin-bottom:4px;display:none;\">%%LABEL_FIX_PARAM_ERR%%</div>
  <div style=\"display:flex;gap:6px;justify-content:flex-end;margin-top:6px;\">
    <button id=\"btnConstraintCancel\" class=\"modal-btn\" style=\"font-size:12px;padding:3px 10px;\">%%LABEL_CANCEL%%</button>
    <button id=\"btnConstraintOK\" class=\"modal-btn primary\" style=\"font-size:12px;padding:3px 10px;\">%%LABEL_OK%%</button>
  </div>
</div>

<!-- ── data injection ──────────────────────────────────────── -->
<script>
(function() {
  var d = window.__SG__ = {};
  try { d.vars      = %%VARS%%;            } catch(e) { d.vars      = []; }
  try { d.model     = %%MODEL_SPEC%%;      } catch(e) { d.model     = {nodes:[],edges:[]}; }
  try { d.latent    = %%LATENT_VARS%%;     } catch(e) { d.latent    = []; }
  try { d.estimates = %%PARAM_ESTIMATES%%; } catch(e) { d.estimates = []; }
  d.showStd       = %%SHOW_STD%%;
  d.hideResiduals = %%HIDE_RESIDUALS%%;
})();
</script>

<!-- ── main editor ─────────────────────────────────────────── -->
<script>
(function() {
  var SG        = window.__SG__;
  var VARS      = SG.vars      || [];
  var LATENT    = SG.latent    || [];
  var ESTIMATES = SG.estimates || [];
  var SHOW_STD       = !!SG.showStd;
  var HIDE_RESIDUALS = !!SG.hideResiduals;

  var model = (SG.model && Array.isArray(SG.model.nodes))
              ? SG.model : {nodes:[], edges:[]};
  if (!Array.isArray(model.nodes)) model.nodes = [];
  if (!Array.isArray(model.edges)) model.edges = [];

  /* Fixed canvas dimensions matching CSS */
  var CANVAS_H = 480;
  var CANVAS_W = 560;

  /* Show estimates on diagram by default if available */
  var showEst = ESTIMATES.length > 0;
  var selId   = null;
  var selType = null;
  var pending = null;
  var dragging = null;
  var mouseX = 0, mouseY = 0;
  var saveTimer = null;
  var errorPos = {}; /* node id → {x,y} of error circle center, rebuilt each render() */

  var svg              = document.getElementById('canvas');
  var ctxNode          = document.getElementById('ctxNode');
  var ctxEdge          = document.getElementById('ctxEdge');
  var ctxError         = document.getElementById('ctxError');
  var renameModal      = document.getElementById('renameModal');
  var renameInput      = document.getElementById('renameInput');
  var constraintPopup  = document.getElementById('constraintPopup');
  var constraintInput  = document.getElementById('constraintInput');
  var constraintError  = document.getElementById('constraintError');
  var btnEst           = document.getElementById('btnEst');

  /* ── helpers ──────────────────────────────────────────── */

  var _c = 0;
  function uid() { return 'n' + (++_c) + Math.random().toString(36).slice(2,5); }

  function findNode(id) {
    for (var i=0; i<model.nodes.length; i++) if (model.nodes[i].id===id) return model.nodes[i];
    return null;
  }

  function svgPt(evt) {
    var pt = svg.createSVGPoint();
    pt.x = evt.clientX; pt.y = evt.clientY;
    return pt.matrixTransform(svg.getScreenCTM().inverse());
  }

  function borderPt(n, tx, ty) {
    var dx=tx-n.x, dy=ty-n.y, d=Math.sqrt(dx*dx+dy*dy);
    if (d<0.001) return {x:n.x,y:n.y};
    var ux=dx/d, uy=dy/d;
    if (n.type==='observed') {
      var t=Math.min(Math.abs(ux)>0?35/Math.abs(ux):1e9, Math.abs(uy)>0?15/Math.abs(uy):1e9);
      return {x:n.x+ux*t, y:n.y+uy*t};
    }
    var a=(ux*ux)/1600+(uy*uy)/484;
    var t2=Math.sqrt(1/a);
    return {x:n.x+ux*t2, y:n.y+uy*t2};
  }

  function getEst(edge) {
    if (!showEst || !ESTIMATES || !ESTIMATES.length) return null;
    var fn=findNode(edge.from), tn=findNode(edge.to);
    if (!fn||!tn) return null;
    var fl=fn.label, tl=tn.label;
    var op = edge.type==='loading' ? '=~' : edge.type==='regression' ? '~' : edge.type==='covariance' ? '~~' : null;
    if (!op) return null;
    for (var i=0;i<ESTIMATES.length;i++) {
      var e=ESTIMATES[i];
      if (e.op!==op) continue;
      if (op==='=~'&&e.lhs===fl&&e.rhs===tl) return e;
      if (op==='~' &&e.lhs===tl&&e.rhs===fl) return e;
      if (op==='~~'&&((e.lhs===fl&&e.rhs===tl)||(e.lhs===tl&&e.rhs===fl))) return e;
    }
    return null;
  }

  function fmtEst(e) {
    if (!e) return '';
    if (SHOW_STD) {
      var sa = e['std.all'];
      return (sa!=null&&!isNaN(+sa)) ? (+sa).toFixed(3) : '';
    } else {
      return e.est!=null ? (+e.est).toFixed(3) : '';
    }
  }

  /* ── save ───────────────────────────────────────────────── */

  function saveNow() {
    if (saveTimer) { clearTimeout(saveTimer); saveTimer=null; }
    if (typeof window.setOption==='function')
      window.setOption('modelSpec', JSON.stringify(model));
  }

  function saveLater() {
    if (saveTimer) clearTimeout(saveTimer);
    saveTimer = setTimeout(function() {
      saveTimer = null;
      if (typeof window.setOption==='function')
        window.setOption('modelSpec', JSON.stringify(model));
    }, 800);
  }

  /* ── rendering ──────────────────────────────────────────── */

  function clearSVG() {
    var ch=svg.childNodes;
    for (var i=ch.length-1;i>=0;i--) { if (ch[i].tagName!=='defs') svg.removeChild(ch[i]); }
  }

  function render() {
    clearSVG();
    /* Pre-compute error node positions so drawArc can route covariance arcs through them */
    errorPos = {};
    if (!HIDE_RESIDUALS && ESTIMATES.length > 0) {
      for (var k=0;k<model.nodes.length;k++) {
        var nd=model.nodes[k];
        for (var ri=0;ri<ESTIMATES.length;ri++) {
          var re=ESTIMATES[ri];
          if (re.op==='~~'&&re.lhs===nd.label&&re.rhs===nd.label) {
            var dir=nd.residualDir||'top', gap=nd.type==='observed'?60:72, ex, ey;
            if      (dir==='bottom'){ex=nd.x;      ey=nd.y+gap;}
            else if (dir==='left')  {ex=nd.x-gap;  ey=nd.y;   }
            else if (dir==='right') {ex=nd.x+gap;  ey=nd.y;   }
            else                    {ex=nd.x;       ey=nd.y-gap;}
            errorPos[nd.id]={x:ex,y:ey};
            break;
          }
        }
      }
    }
    for (var i=0;i<model.edges.length;i++) drawEdgeEl(model.edges[i]);
    if (pending) {
      var fn=findNode(pending.fromId);
      if (fn) {
        var fp=errorPos[fn.id];
        svg.appendChild(mkEl('line',{class:'edge-preview',x1:fp?fp.x:fn.x,y1:fp?fp.y:fn.y,x2:mouseX,y2:mouseY}));
      }
    }
    for (var j=0;j<model.nodes.length;j++) drawNodeEl(model.nodes[j]);
    /* Draw error/disturbance nodes when hideResiduals is off and estimates exist */
    if (!HIDE_RESIDUALS && ESTIMATES.length > 0) {
      var eIdx=0, dIdx=0;
      for (var k=0;k<model.nodes.length;k++) {
        var nd=model.nodes[k];
        var hasRes=false;
        for (var ri=0;ri<ESTIMATES.length;ri++) {
          var re=ESTIMATES[ri];
          if (re.op==='~~'&&re.lhs===nd.label&&re.rhs===nd.label){hasRes=true;break;}
        }
        if (hasRes) {
          var errIdx = nd.type==='latent' ? ++dIdx : ++eIdx;
          drawResidualEl(nd, errIdx);
        }
      }
    }
    btnEst.classList.toggle('active', showEst && ESTIMATES.length>0);
    if (model.nodes.length > 0 && model.edges.length === 0 && !pending) {
      var hint = mkEl('text', {'x':'50%','y':'50%','text-anchor':'middle','dominant-baseline':'middle','class':'canvas-hint'});
      hint.textContent = '%%LABEL_HINT_RIGHTCLICK%%';
      svg.appendChild(hint);
    }
  }

  function mkEl(tag, attrs) {
    var el=document.createElementNS('http://www.w3.org/2000/svg',tag);
    for (var k in attrs) el.setAttribute(k,attrs[k]);
    return el;
  }

  function drawNodeEl(n) {
    var isSel=selId===n.id&&selType==='node';
    var g=mkEl('g',{class:'node node-'+n.type+(isSel?' node-selected':''),'data-id':n.id});
    if (n.type==='observed') {
      g.appendChild(mkEl('rect',{x:n.x-35,y:n.y-15,width:70,height:30,rx:3}));
    } else {
      g.appendChild(mkEl('ellipse',{cx:n.x,cy:n.y,rx:40,ry:22}));
    }
    var t=mkEl('text',{class:'node-label',x:n.x,y:n.y}); t.textContent=n.label;
    g.appendChild(t);
    g.addEventListener('mousedown', onNodeMD);
    g.addEventListener('click',     onNodeClick);
    g.addEventListener('dblclick',  onNodeDbl);
    g.addEventListener('contextmenu', onNodeCtx);
    svg.appendChild(g);
  }

  function drawEdgeEl(edge) {
    var fn=findNode(edge.from), tn=findNode(edge.to);
    if (!fn||!tn) return;
    var isSel=selId===edge.id&&selType==='edge';
    var constrained=edge.constraint!=null&&edge.constraint!=='';
    var g=mkEl('g',{'data-id':edge.id,class:'edge edge-'+edge.type+(isSel?' edge-selected':'')+(constrained?' edge-constrained':'')});
    if (fn.id===tn.id)              drawSelfLoop(g,fn,isSel,edge);
    else if (edge.type==='covariance') drawArc(g,fn,tn,isSel,edge);
    else                            drawArrow(g,fn,tn,isSel,edge);
    g.addEventListener('click',      onEdgeClick);
    g.addEventListener('contextmenu',onEdgeCtx);
    svg.appendChild(g);
  }

  function drawArrow(g,fn,tn,isSel,edge) {
    var p1=borderPt(fn,tn.x,tn.y), p2=borderPt(tn,fn.x,fn.y);
    var dx=p2.x-p1.x, dy=p2.y-p1.y, d=Math.sqrt(dx*dx+dy*dy);
    var x2=d>0?p2.x-dx/d*9:p2.x, y2=d>0?p2.y-dy/d*9:p2.y;
    var constrained=edge.constraint!=null&&edge.constraint!=='';
    g.appendChild(mkEl('line',{class:'edge-'+edge.type,x1:p1.x,y1:p1.y,x2:x2,y2:y2,
      'marker-end':'url(#'+(isSel||constrained?'arr-sel':'arr')+')'}));
    g.appendChild(mkEl('line',{x1:p1.x,y1:p1.y,x2:p2.x,y2:p2.y,stroke:'transparent','stroke-width':10}));
    var mx=(p1.x+p2.x)/2, my=(p1.y+p2.y)/2-9;
    if (edge.constraint!=null&&edge.constraint!=='') {
      var ct=mkEl('text',{class:'constraint-lbl',x:mx,y:my}); ct.textContent=edge.constraint; g.appendChild(ct);
    } else { var e=getEst(edge); if (e){var t=mkEl('text',{class:'est-lbl',x:mx,y:my}); t.textContent=fmtEst(e); g.appendChild(t);} }
  }

  function drawArc(g,fn,tn,isSel,edge) {
    var er=13;
    var fp=errorPos[fn.id], tp=errorPos[tn.id];
    var fx=fp?fp.x:fn.x, fy=fp?fp.y:fn.y;
    var tx=tp?tp.x:tn.x, ty=tp?tp.y:tn.y;
    var mx=(fx+tx)/2, my=(fy+ty)/2;
    var dx=tx-fx, dy=ty-fy, len=Math.sqrt(dx*dx+dy*dy);
    var cx=mx+(-dy/(len||1)*55), cy=my+(dx/(len||1)*55);
    function errBdr(c,t){var ddx=t.x-c.x,ddy=t.y-c.y,dd=Math.sqrt(ddx*ddx+ddy*ddy);
      return dd>0?{x:c.x+ddx/dd*er,y:c.y+ddy/dd*er}:c;}
    var p1=fp?errBdr(fp,{x:cx,y:cy}):borderPt(fn,cx,cy);
    var p2=tp?errBdr(tp,{x:cx,y:cy}):borderPt(tn,cx,cy);
    var pd='M'+p1.x+' '+p1.y+' Q'+cx+' '+cy+' '+p2.x+' '+p2.y;
    var constrained=edge.constraint!=null&&edge.constraint!=='';
    var suf=isSel||constrained?'-sel':'';
    g.appendChild(mkEl('path',{class:'edge-covariance',d:pd,
      'marker-start':'url(#arr-s'+suf+')','marker-end':'url(#arr'+suf+')'}));
    g.appendChild(mkEl('path',{d:pd,stroke:'transparent','stroke-width':10,fill:'none'}));
    if (edge.constraint!=null&&edge.constraint!=='') {
      var ct=mkEl('text',{class:'constraint-lbl',x:cx,y:cy-8}); ct.textContent=edge.constraint; g.appendChild(ct);
    } else { var e=getEst(edge); if (e){var t=mkEl('text',{class:'est-lbl',x:cx,y:cy-8}); t.textContent=fmtEst(e); g.appendChild(t);} }
  }

  function drawSelfLoop(g,n,isSel,edge) {
    var ox=n.type==='observed'?n.x+28:n.x+33, oy=n.type==='observed'?n.y-15:n.y-18, r=18;
    var d='M'+ox+' '+(oy+r)+' A'+r+' '+r+' 0 1 1 '+(ox+r)+' '+oy;
    g.appendChild(mkEl('path',{class:'edge-covariance',d:d,'marker-end':'url(#arr'+(isSel?'-sel':'')+')'}));
    var e=getEst(edge);
    if (e) { var t=mkEl('text',{class:'est-lbl',x:ox+r+6,y:oy-6}); t.textContent=fmtEst(e); g.appendChild(t); }
  }

  /* Draw error/disturbance node with straight arrow to target (standard SEM notation) */
  function drawResidualEl(n, idx) {
    var resEst = null;
    for (var i=0;i<ESTIMATES.length;i++) {
      var e=ESTIMATES[i];
      if (e.op==='~~'&&e.lhs===n.label&&e.rhs===n.label){resEst=e;break;}
    }
    if (!resEst) return;

    var prefix = n.type==='latent' ? 'd' : 'e';
    var errLabel = prefix + idx;
    var er = 13;
    var gap = n.type==='observed' ? 60 : 72;

    /* Position based on residualDir stored in node */
    var dir = n.residualDir || 'top';
    var ex, ey;
    if      (dir === 'bottom') { ex = n.x;       ey = n.y + gap; }
    else if (dir === 'left')   { ex = n.x - gap; ey = n.y;       }
    else if (dir === 'right')  { ex = n.x + gap; ey = n.y;       }
    else                       { ex = n.x;       ey = n.y - gap; } /* top (default) */

    /* Error/disturbance circle — right-clickable, click completes pending covariance */
    var cg = mkEl('g', {class:'node node-error', 'data-error-for':n.id});
    cg.appendChild(mkEl('circle', {cx:ex, cy:ey, r:er}));
    var ct = mkEl('text', {class:'error-label', x:ex, y:ey});
    ct.textContent = errLabel;
    cg.appendChild(ct);
    cg.addEventListener('contextmenu', onErrorCtx);
    cg.addEventListener('click',       onErrorClick);
    svg.appendChild(cg);

    /* Arrow: from circle border toward target → to target border */
    var p2 = borderPt(n, ex, ey);
    var dx = p2.x - ex, dy = p2.y - ey;
    var dist = Math.sqrt(dx*dx + dy*dy);
    var sx = dist>0 ? ex + dx/dist*er : ex;
    var sy = dist>0 ? ey + dy/dist*er : ey;
    var x2 = dist>0 ? p2.x - dx/dist*9 : p2.x;
    var y2 = dist>0 ? p2.y - dy/dist*9 : p2.y;
    var ag = mkEl('g', {class:'edge edge-regression', 'pointer-events':'none'});
    ag.appendChild(mkEl('line', {class:'edge-regression',
      x1:sx, y1:sy, x2:x2, y2:y2, 'marker-end':'url(#arr)'}));

    if (showEst) {
      var lbl = SHOW_STD
        ? (resEst['std.all']!=null&&!isNaN(+resEst['std.all']) ? (+resEst['std.all']).toFixed(3) : '')
        : (resEst.est!=null ? (+resEst.est).toFixed(3) : '');
      if (lbl) {
        var lt = mkEl('text',{class:'est-lbl',x:(sx+p2.x)/2+8,y:(sy+p2.y)/2});
        lt.textContent=lbl; ag.appendChild(lt);
      }
    }
    svg.appendChild(ag);
  }

  /* ── variable sync ──────────────────────────────────────── */

  function syncVars() {
    /* Use fixed canvas dimensions — never rely on svg.clientHeight which may be
       unreliable depending on when the script runs vs. when CSS is applied. */
    var W = Math.max(svg.getBoundingClientRect().width || 0, CANVAS_W);
    var H = CANVAS_H;

    var obsCols = Math.max(1, Math.floor((W - 45) / 90));
    VARS.forEach(function(v) {
      if (!model.nodes.find(function(n){return n.label===v&&n.type==='observed';})) {
        var idx=model.nodes.filter(function(n){return n.type==='observed';}).length;
        var col=idx%obsCols, row=Math.floor(idx/obsCols);
        model.nodes.push({id:uid(),label:v,type:'observed',
          x:60+col*90, y:Math.round(H*0.72)+row*70});
      }
    });
    model.nodes=model.nodes.filter(function(n){return n.type!=='observed'||VARS.indexOf(n.label)>=0;});
    LATENT.forEach(function(v) {
      if (!model.nodes.find(function(n){return n.label===v&&n.type==='latent';})) {
        var idx=model.nodes.filter(function(n){return n.type==='latent';}).length;
        model.nodes.push({id:uid(),label:v,type:'latent',x:120+idx*130,y:Math.round(H*0.28)});
      }
    });
    model.nodes=model.nodes.filter(function(n){return n.type!=='latent'||LATENT.indexOf(n.label)>=0;});
    var ids={}; model.nodes.forEach(function(n){ids[n.id]=true;});
    model.edges=model.edges.filter(function(e){return ids[e.from]&&ids[e.to];});
  }

  /* ── auto layout ────────────────────────────────────────── */

  function autoLayout() {
    var W = Math.max(svg.getBoundingClientRect().width || 0, CANVAS_W);
    var H = CANVAS_H;
    var lat=model.nodes.filter(function(n){return n.type==='latent';});
    var obs=model.nodes.filter(function(n){return n.type==='observed';});
    lat.forEach(function(n,i){n.x=Math.round(W*(i+1)/(lat.length+1));n.y=Math.round(H*0.28);});
    obs.forEach(function(n,i){n.x=Math.round(W*(i+1)/(obs.length+1));n.y=Math.round(H*0.72);});
    saveNow(); render();
  }

  /* ── edge helpers ───────────────────────────────────────── */

  function autoEdgeType(fn,tn) {
    if (fn.id===tn.id) return 'covariance';
    if (fn.type==='latent'&&tn.type==='observed') return 'loading';
    return 'regression';
  }

  function addEdge(fromId,toId,forcedType) {
    var fn=findNode(fromId), tn=findNode(toId); if (!fn||!tn) return;
    var type=forcedType||autoEdgeType(fn,tn);
    if (fromId!==toId&&type!=='covariance') {
      if (model.edges.find(function(e){return e.from===fromId&&e.to===toId;})) return;
    }
    model.edges.push({id:uid(),from:fromId,to:toId,type:type});
    saveNow(); render();
  }

  function deleteItem(id,type) {
    if (type==='node') {
      model.nodes=model.nodes.filter(function(n){return n.id!==id;});
      model.edges=model.edges.filter(function(e){return e.from!==id&&e.to!==id;});
    } else {
      model.edges=model.edges.filter(function(e){return e.id!==id;});
    }
    if (selId===id){selId=null;selType=null;}
    saveNow(); render();
  }

  /* ── node events ────────────────────────────────────────── */

  function onNodeMD(evt) {
    evt.stopPropagation();
    if (evt.button!==0||pending) return;
    var id=this.getAttribute('data-id'), n=findNode(id); if (!n) return;
    var pt=svgPt(evt);
    dragging={nodeId:id,ox:pt.x-n.x,oy:pt.y-n.y};
    selId=id; selType='node'; render();
  }

  function onNodeClick(evt) {
    evt.stopPropagation();
    if (evt.button!==0) return;
    var id=this.getAttribute('data-id');
    if (pending) {
      addEdge(pending.fromId,id,pending.edgeType);
      pending=null; svg.classList.remove('pending'); return;
    }
    selId=id; selType='node'; render();
  }

  function onNodeDbl(evt) {
    evt.stopPropagation();
    var n=findNode(this.getAttribute('data-id'));
    if (n&&n.type==='latent') openRename(n);
  }

  function onNodeCtx(evt) {
    evt.preventDefault(); evt.stopPropagation();
    var id=this.getAttribute('data-id'), n=findNode(id);
    ctxNode._tid=id;
    /* \"因子負荷を追加\" only for latent nodes */
    document.getElementById('ctxAddLoading').style.display = (n&&n.type==='latent') ? '' : 'none';
    ctxNode.style.left=evt.clientX+'px'; ctxNode.style.top=evt.clientY+'px';
    ctxNode.classList.remove('hidden'); ctxEdge.classList.add('hidden');
    selId=id; selType='node'; render();
  }

  /* ── error node events ──────────────────────────────────── */

  function onErrorCtx(evt) {
    evt.preventDefault(); evt.stopPropagation();
    ctxError._targetId = this.getAttribute('data-error-for');
    ctxError.style.left = evt.clientX+'px'; ctxError.style.top = evt.clientY+'px';
    ctxError.classList.remove('hidden');
    ctxNode.classList.add('hidden'); ctxEdge.classList.add('hidden');
  }

  function onErrorClick(evt) {
    evt.stopPropagation();
    if (evt.button!==0) return;
    if (pending) {
      addEdge(pending.fromId, this.getAttribute('data-error-for'), pending.edgeType);
      pending=null; svg.classList.remove('pending'); render();
    }
  }

  /* ── edge events ────────────────────────────────────────── */

  function onEdgeClick(evt) {
    evt.stopPropagation();
    if (evt.button!==0) return;
    if (pending){pending=null;svg.classList.remove('pending');render();return;}
    selId=this.getAttribute('data-id'); selType='edge'; render();
  }

  function onEdgeCtx(evt) {
    evt.preventDefault(); evt.stopPropagation();
    var id=this.getAttribute('data-id');
    var edge=model.edges.find(function(e){return e.id===id;});
    ctxEdge._tid=id;
    var constrained=edge&&edge.constraint!=null&&edge.constraint!=='';
    document.getElementById('ctxRemoveConstraint').style.display=constrained?'':'none';
    ctxEdge._cx=evt.clientX; ctxEdge._cy=evt.clientY;
    ctxEdge.style.left=evt.clientX+'px'; ctxEdge.style.top=evt.clientY+'px';
    ctxEdge.classList.remove('hidden'); ctxNode.classList.add('hidden');
    selId=id; selType='edge'; render();
  }

  /* ── canvas events ──────────────────────────────────────── */

  svg.addEventListener('mousemove', function(evt) {
    if (dragging) {
      var pt=svgPt(evt), n=findNode(dragging.nodeId);
      if (n){n.x=pt.x-dragging.ox;n.y=pt.y-dragging.oy;} render();
    } else if (pending) {
      var pt2=svgPt(evt); mouseX=pt2.x; mouseY=pt2.y; render();
    }
  });

  svg.addEventListener('mouseup', function() {
    if (dragging) { saveLater(); dragging=null; }
  });

  svg.addEventListener('click', function(evt) {
    if (evt.button!==0) return;
    if (pending){pending=null;svg.classList.remove('pending');render();return;}
    selId=null;selType=null;
    ctxNode.classList.add('hidden');ctxEdge.classList.add('hidden');render();
  });

  svg.addEventListener('contextmenu', function(evt){evt.preventDefault();});

  document.addEventListener('click', function(){
    ctxNode.classList.add('hidden'); ctxEdge.classList.add('hidden');
    ctxError.classList.add('hidden'); constraintPopup.classList.add('hidden');
  });

  document.addEventListener('keydown', function(evt) {
    var tag=document.activeElement?document.activeElement.tagName:'';
    if (tag==='INPUT'||tag==='TEXTAREA') return;
    if (evt.key==='Escape') {
      pending=null; svg.classList.remove('pending');
      ctxNode.classList.add('hidden'); ctxEdge.classList.add('hidden');
      ctxError.classList.add('hidden'); constraintPopup.classList.add('hidden'); render();
    } else if ((evt.key==='Delete'||evt.key==='Backspace')&&selId) {
      deleteItem(selId,selType);
    }
  });

  /* ── context menus ──────────────────────────────────────── */

  ctxNode.addEventListener('click', function(evt) {
    evt.stopPropagation();
    var action=evt.target.getAttribute('data-action'), tid=ctxNode._tid;
    ctxNode.classList.add('hidden'); if (!action||!tid) return;
    if (action==='addLoading') {
      pending={fromId:tid,edgeType:'loading'}; svg.classList.add('pending'); render();
    } else if (action==='addRegression') {
      pending={fromId:tid,edgeType:'regression'}; svg.classList.add('pending'); render();
    } else if (action==='addCovariance') {
      pending={fromId:tid,edgeType:'covariance'}; svg.classList.add('pending'); render();
    }
  });

  ctxEdge.addEventListener('click', function(evt) {
    evt.stopPropagation();
    var action=evt.target.getAttribute('data-action'), tid=ctxEdge._tid;
    ctxEdge.classList.add('hidden');
    if (action==='deleteEdge'&&tid) deleteItem(tid,'edge');
    else if (action==='fixValue'&&tid) openConstraint(tid, ctxEdge._cx, ctxEdge._cy);
    else if (action==='removeConstraint'&&tid) {
      var edge=model.edges.find(function(e){return e.id===tid;});
      if (edge){edge.constraint=null;saveNow();render();}
    }
  });

  /* ── constraint modal ───────────────────────────────────── */

  function openConstraint(eid, cx, cy) {
    var edge=model.edges.find(function(e){return e.id===eid;}); if (!edge) return;
    constraintPopup._eid=eid;
    constraintInput.value = (edge.constraint!=null) ? edge.constraint : '';
    constraintError.style.display='none'; constraintInput.style.borderColor='';
    /* Position near click, clamp to viewport */
    var pw=200, ph=110;
    constraintPopup.style.left=Math.min(cx, window.innerWidth -pw-10)+'px';
    constraintPopup.style.top =Math.min(cy, window.innerHeight-ph-10)+'px';
    constraintPopup.classList.remove('hidden');
    constraintInput.focus(); constraintInput.select();
  }

  function closeConstraint(save) {
    if (save) {
      var val=constraintInput.value.trim();
      if (val!==''&&!isFinite(parseFloat(val))) {
        constraintError.style.display='block'; constraintInput.style.borderColor='#c62828'; return;
      }
      var edge=model.edges.find(function(e){return e.id===constraintPopup._eid;});
      if (edge) { edge.constraint=val===''?null:String(parseFloat(val)); saveNow(); render(); }
    }
    constraintError.style.display='none'; constraintInput.style.borderColor='';
    constraintPopup.classList.add('hidden');
  }

  /* Clicks inside popup don't propagate to document (which would close it) */
  constraintPopup.addEventListener('click', function(evt){evt.stopPropagation();});
  document.getElementById('btnConstraintOK').addEventListener('click',function(){closeConstraint(true);});
  document.getElementById('btnConstraintCancel').addEventListener('click',function(){closeConstraint(false);});
  constraintInput.addEventListener('keydown',function(evt){
    if (evt.key==='Enter') closeConstraint(true);
    if (evt.key==='Escape') closeConstraint(false);
  });

  ctxError.addEventListener('click', function(evt) {
    evt.stopPropagation();
    var action=evt.target.getAttribute('data-action');
    var tid=ctxError._targetId;
    ctxError.classList.add('hidden');
    if (!action||!tid) return;
    var node=findNode(tid); if (!node) return;
    if (action==='errPosTop'||action==='errPosBottom'||
        action==='errPosLeft'||action==='errPosRight') {
      node.residualDir = action.slice(6).toLowerCase(); /* 'errPosTop' → 'top' */
      saveNow(); render();
    } else if (action==='errCov') {
      pending={fromId:tid,edgeType:'covariance'};
      svg.classList.add('pending'); render();
    }
  });

  /* ── toolbar ────────────────────────────────────────────── */

  document.getElementById('btnLayout').addEventListener('click', autoLayout);

  btnEst.addEventListener('click', function() {
    showEst = !showEst;
    render();
  });

  /* ── rename modal ───────────────────────────────────────── */

  var renameError = document.getElementById('renameError');

  function openRename(n) {
    renameModal._nid=n.id; renameInput.value=n.label;
    renameError.style.display='none'; renameInput.style.borderColor='';
    renameModal.classList.remove('hidden'); renameInput.focus(); renameInput.select();
  }
  function closeRename(save) {
    if (save) {
      var n=findNode(renameModal._nid);
      if (n) {
        var newLabel=renameInput.value.trim()||n.label;
        if (VARS.indexOf(newLabel)>=0) {
          renameError.style.display='block';
          renameInput.style.borderColor='#c62828';
          return;
        }
        n.label=newLabel; saveNow(); render();
      }
    }
    renameError.style.display='none'; renameInput.style.borderColor='';
    renameModal.classList.add('hidden');
  }
  document.getElementById('btnRenameOK').addEventListener('click',function(){closeRename(true);});
  document.getElementById('btnRenameCancel').addEventListener('click',function(){closeRename(false);});
  renameInput.addEventListener('keydown',function(evt){
    if (evt.key==='Enter') closeRename(true);
    if (evt.key==='Escape') closeRename(false);
  });

  /* ── init ───────────────────────────────────────────────── */

  syncVars();
  render();

})();
</script>

</body>
</html>"
