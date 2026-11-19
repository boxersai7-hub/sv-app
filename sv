<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>SV Enterprises — Service Manager</title>
<style>
:root{--bg:#f3f6fb;--ink:#17243b;--muted:#68758a;--brand:#175cd3;--line:#dce3ee}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:15px system-ui,sans-serif}
header{background:#102440;color:white;padding:22px max(20px,calc((100vw - 1150px)/2))}
header h1{margin:0;font-size:24px}header p{opacity:.75;margin:7px 0}
main{max-width:1190px;margin:auto;padding:20px}
nav,.toolbar,.row{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
nav{margin:20px 0}
button{border:0;background:var(--brand);color:white;padding:11px 16px;border-radius:9px;cursor:pointer;font:inherit}
button.secondary{background:#e7edf7;color:var(--ink)}
button.active{background:#102440}
button:disabled{opacity:.5;cursor:wait}
.card{background:white;border:1px solid var(--line);padding:20px;border-radius:14px;margin-bottom:16px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:16px}
label{display:block;font-size:13px;font-weight:600;margin:12px 0}
input,select,textarea{display:block;width:100%;padding:11px;border:1px solid #cbd5e1;border-radius:8px;margin-top:6px;font:inherit;background:white}
textarea{min-height:80px}
h2{font-size:21px;margin-top:0}h3{margin:6px 0 12px}
small,.muted{color:var(--muted)}
.badge{display:inline-block;background:#edf3ff;padding:5px 9px;border-radius:20px;font-size:12px}
.stat{font-size:32px;font-weight:750}
.notice{background:#fff6d9;border:1px solid #efdc97;padding:14px;border-radius:10px;margin-bottom:18px}
canvas{display:block;background:#fff;border:1px dashed #8a9bb5;border-radius:8px;width:100%;height:150px;touch-action:none}
table{border-collapse:collapse;width:100%}td,th{text-align:left;padding:10px;border-bottom:1px solid var(--line)}
.scroll{overflow:auto}
.photos img{max-width:180px;max-height:160px;object-fit:contain;margin:5px}
.signature{max-width:260px;max-height:110px}
#toast{position:fixed;bottom:20px;left:50%;transform:translateX(-50%);background:#102440;color:white;padding:12px 20px;border-radius:10px;display:none;z-index:10}
@media print{
body{background:white}header,nav,.toolbar,.notice,.no-print,#toast{display:none!important}
main{padding:0;max-width:none}.card{border:0;padding:8px}.photos img{max-width:150px}
}
</style>
</head>
<body>
<header>
<h1>SV Enterprises</h1>
<p>Generator Service & AMC Management</p>
</header>
<main>
<div class="notice">
<strong>Local prototype:</strong> No secure login or automatic WhatsApp delivery.
Use sample data only. Photos can fill browser storage.
</div>
<div class="toolbar">
<label>Demo role
<select id="role">
<option value="owner">Proprietor</option>
<option value="tech">Technician</option>
</select>
</label>
<label id="techPicker" hidden>Technician
<select id="tech"></select>
</label>
</div>
<nav id="nav"></nav>
<section id="app"></section>
</main>
<div id="toast" role="status"></div>
<script>
"use strict";
const $ = id => document.getElementById(id);
const uid = () => crypto.randomUUID();
const esc = value => String(value ?? "").replace(/[&<>"']/g,
 c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const today = () => {
 const d = new Date();
 return ${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,"0")}-${String(d.getDate()).padStart(2,"0")};
};
const initial = () => ({
 customers:[], generators:[], amcs:[], jobs:[], reports:[],
 technicians:[{id:uid(),name:"Technician 1"}]
});
let db;
try { db=JSON.parse(localStorage.getItem("sv-enterprises-v1")) || initial(); }
catch { db=initial(); }
let page="Dashboard";
let openedReport=null;
function persist(next){
 localStorage.setItem("sv-enterprises-v1",JSON.stringify(next));
 db=next;
}
function commit(action){
 const next=structuredClone(db);
 action(next);
 persist(next);
}
function notify(message){
 $("toast").textContent=message;$("toast").style.display="block";
 setTimeout(()=>$("toast").style.display="none",4000);
}
function customer(id){return db.customers.find(x=>x.id===id);}
function generator(id){return db.generators.find(x=>x.id===id);}
function genName(id){
 const g=generator(id);
 return g?${customer(g.customerId)?.name || ""} — ${g.make} ${g.kva} kVA (${g.model}):"Unknown";
}
function options(items,label){
 return items.map(x=><option value="${esc(x.id)}">${esc(label(x))}</option>).join("");
}
function field(label,name,type="text",extra=""){
 return <label>${label}<input name="${name}" type="${type}" required ${extra}></label>;
}
function selectField(label,name,items,labeler){
 return `<label>${label}<select name="${name}" required>
 <option value="">Select…</option>${options(items,labeler)}</select></label>`;
}
function formCard(title,body){
 return `<form class="card" id="entry"><h2>${title}</h2>${body}
 <button type="submit">Save</button></form>`;
}
function empty(text){return <div class="card muted">${text}</div>;}
function bindEntry(handler){
 $("entry").onsubmit=e=>{
  e.preventDefault();
  try{
   handler(Object.fromEntries(new FormData(e.currentTarget)));
   notify("Saved");render();
  }catch(error){notify(error.message || "Unable to save");}
 };
}
function render(){
 const owner=$("role").value==="owner";
 $("techPicker").hidden=owner;
 const selected=$("tech").value;
 $("tech").innerHTML=options(db.technicians,x=>x.name);
 if(db.technicians.some(x=>x.id===selected))$("tech").value=selected;
 const tabs=owner?["Dashboard","Customers","Generators","AMC","Services","Reports","Technicians"]:["My Services"];
 if(!tabs.includes(page))page=tabs[0];
 $("nav").innerHTML=tabs.map(t=><button class="${page===t?"active":"secondary"}" data-page="${t}">${t}</button>).join("");
 $("nav").querySelectorAll("button").forEach(b=>b.onclick=()=>{page=b.dataset.page;render();});
 const views={"Dashboard":dashboard,"Customers":customersView,"Generators":generatorsView,
 "AMC":amcView,"Services":servicesView,"Reports":reportsView,
 "Technicians":techniciansView,"My Services":myServices};
 views[page]();
}
$("role").onchange=render;
$("tech").onchange=render;

function dashboard(){
 const active=db.amcs.filter(a=>a.start<=today()&&a.end>=today());
 const upcoming=db.amcs.map(a=>({...a,days:Math.round(
 (Date.parse(a.end+"T00:00:00Z")-Date.parse(today()+"T00:00:00Z"))/86400000
 )})).filter(a=>a.days>=0&&a.days<=30);
 $("app").innerHTML=`
 <div class="grid">
 ${[
 ["Customers",db.customers.length],["Generators",db.generators.length],
 ["Active AMCs",active.length],["Open Services",db.jobs.filter(j=>j.status==="Assigned").length]
 ].map(([k,v])=><div class="card"><small>${k}</small><div class="stat">${v}</div></div>).join("")}
 </div>
 <div class="card"><h2>Upcoming AMC Expiries</h2>
 <p class="muted">30 / 15 / 7-day reminder milestones are tracked here.
 Automatic messaging is not connected.</p>
 ${upcoming.length?upcoming.map(a=>`<p><strong>${esc(genName(a.generatorId))}</strong><br>
 Expires ${esc(a.end)} · ${a.days} day(s) remaining
 ${[30,15,7].includes(a.days)?'<span class="badge">Reminder due today</span>':""}</p>`).join(""):"No AMCs expire in the next 30 days."}
 </div>`;
}
function customersView(){
 $("app").innerHTML=formCard("Add Customer",`
 <div class="grid">${field("Customer Name","name")}
 ${field("WhatsApp Number with Country Code","phone","tel")}
 </div><label>Address<textarea name="address" required></textarea></label>`)
 +db.customers.map(c=>`<div class="card"><h3>${esc(c.name)}</h3>
 <p>${esc(c.phone)}</p><p>${esc(c.address)}</p></div>`).join("");
 bindEntry(v=>commit(d=>d.customers.push({id:uid(),...v})));
}
function generatorsView(){
 $("app").innerHTML=formCard("Add Generator",`
 ${selectField("Customer","customerId",db.customers,x=>x.name)}
 <div class="grid">${field("Make","make")}${field("Capacity (kVA)","kva","number",'min="0.1" step="any"')}
 ${field("Model","model")}${field("Serial / Asset Number","serial")}</div>`)
 +db.generators.map(g=>`<div class="card"><h3>${esc(genName(g.id))}</h3>
 <small>Asset: ${esc(g.serial)}</small></div>`).join("");
 bindEntry(v=>commit(d=>d.generators.push({id:uid(),...v})));
}
function amcView(){
 $("app").innerHTML=formCard("Create AMC",`
 ${selectField("Generator","generatorId",db.generators,x=>genName(x.id))}
 <div class="grid">${field("Start Date","start","date")}
 ${field("End Date","end","date")}
 ${field("Included Visits for This Contract","visits","number",'min="1" step="1" value="12"')}</div>
 <p class="muted">Calendar-month rule: the first eligible completed service deducts one visit.
 Further services in that month are breakdown visits.</p>`)
 +db.amcs.map(a=>`<div class="card"><h3>${esc(genName(a.generatorId))}</h3>
 <p>${esc(a.start)} → ${esc(a.end)}</p>
 <span class="badge">${a.visits-a.usedMonths.length} / ${a.visits} visits remaining</span>
 </div>`).join("");
 bindEntry(v=>{
  if(v.end<v.start)throw Error("End date must not precede start date.");
  if(db.amcs.some(a=>a.generatorId===v.generatorId&&a.start<=v.end&&a.end>=v.start))
   throw Error("This generator already has an overlapping AMC.");
  commit(d=>d.amcs.push({id:uid(),...v,visits:Number(v.visits),usedMonths:[]}));
 });
}
function techniciansView(){
 $("app").innerHTML=formCard("Add Technician",field("Technician Name","name"))
 +db.technicians.map(t=><div class="card">${esc(t.name)}</div>).join("");
 bindEntry(v=>commit(d=>d.technicians.push({id:uid(),...v})));
}
function servicesView(){
 $("app").innerHTML=formCard("Assign Service",`
 ${selectField("Generator","generatorId",db.generators,x=>genName(x.id))}
 ${selectField("Technician","technicianId",db.technicians,x=>x.name)}
 ${field("Scheduled Date","date","date",value="${today()}")}
 <label>Service Notes<textarea name="notes"></textarea></label>`)
 +db.jobs.map(j=>`<div class="card"><h3>${esc(genName(j.generatorId))}</h3>
 <p>${esc(db.technicians.find(t=>t.id===j.technicianId)?.name)} · ${esc(j.date)}</p>
 <span class="badge">${esc(j.status)}</span><p>${esc(j.notes)}</p></div>`).join("");
 bindEntry(v=>commit(d=>d.jobs.push({id:uid(),...v,status:"Assigned"})));
}
function myServices(){
 const jobs=db.jobs.filter(j=>j.technicianId===$("tech").value&&j.status==="Assigned");
 $("app").innerHTML=jobs.length?jobs.map(j=>{
  const g=generator(j.generatorId),c=customer(g.customerId);
  return `<div class="card"><h3>${esc(genName(j.generatorId))}</h3>
  <p>${esc(c.address)}<br>${esc(c.phone)}</p><p>${esc(j.date)} · ${esc(j.notes)}</p>
  <button data-job="${j.id}">Complete Service Report</button></div>`;
 }).join(""):empty("No assigned services. Submitted reports are not available in this view.");
 $("app").querySelectorAll("[data-job]").forEach(b=>b.onclick=()=>fsrView(b.dataset.job));
}

const checks=["Oil Level","Coolant","Filters","Battery","Electrical Readings"];
const readings=[
 ["Running Hours","hours"],["Battery Voltage (V)","battery"],
 ["R–N Voltage (V)","rv"],["Y–N Voltage (V)","yv"],["B–N Voltage (V)","bv"],
 ["N–Earth Voltage (V)","nv"],
 ["R Current (A)","ra"],["Y Current (A)","ya"],["B Current (A)","ba"],["Neutral Current (A)","na"]
];
function signature(canvas){
 const ctx=canvas.getContext("2d");
 canvas.width=900;canvas.height=300;
 ctx.lineWidth=3;ctx.lineCap="round";ctx.strokeStyle="#102440";
 let drawing=false,marked=false;
 function pos(e){
  const r=canvas.getBoundingClientRect();
  return [(e.clientX-r.left)*canvas.width/r.width,(e.clientY-r.top)*canvas.height/r.height];
 }
 canvas.onpointerdown=e=>{
  drawing=true;canvas.setPointerCapture(e.pointerId);
  const [x,y]=pos(e);ctx.beginPath();ctx.moveTo(x,y);
 };
 canvas.onpointermove=e=>{
  if(!drawing)return;
  const [x,y]=pos(e);ctx.lineTo(x,y);ctx.stroke();marked=true;
 };
 canvas.onpointerup=canvas.onpointercancel=()=>drawing=false;
 return {
  valid:()=>marked,
  data:()=>canvas.toDataURL("image/png"),
  clear:()=>{ctx.clearRect(0,0,canvas.width,canvas.height);marked=false;}
 };
}
function fsrView(jobId){
 const job=db.jobs.find(j=>j.id===jobId);
 if(!job||job.status!=="Assigned"||job.technicianId!==$("tech").value)return render();
 $("app").innerHTML=`<form id="fsr" class="card">
 <h2>Field Service Report</h2><p>${esc(genName(job.generatorId))}</p>
 ${field("Service Completion Date","completedDate","date",value="${today()}" max="${today()}")}
 <h3>Readings</h3><div class="grid">
 ${readings.map(([label,key])=>field(label,key,"number",'min="0" step="any"')).join("")}</div>
 <h3>Inspection Checklist</h3>
 ${checks.map((name,i)=>`<div class="card">
 <label>${name}<select name="check${i}" data-check="${i}" required>
 <option value="">Select…</option><option value="OK">OK</option><option value="Not OK">Not OK</option>
 </select></label><div id="issue${i}" hidden>
 <label>Reason<textarea name="reason${i}"></textarea></label>
 <label>Issue Photo<input type="file" name="photo${i}" accept="image/*"></label>
 </div></div>`).join("")}
 <div class="grid">
 <label>Before Cleaning Photo<input name="before" type="file" accept="image/*" required></label>
 <label>After Cleaning Photo<input name="after" type="file" accept="image/*" required></label>
 </div>
 <label>Work Performed / Remarks<textarea name="remarks" required></textarea></label>
 <div class="grid">
 <div><label>Technician Signature</label><canvas id="techSign"></canvas>
 <button type="button" class="secondary" id="clearTech">Clear</button></div>
 <div><label>Customer Signature</label><canvas id="customerSign"></canvas>
 <button type="button" class="secondary" id="clearCustomer">Clear</button></div>
 </div>
 <label>Customer Rating<select name="rating" required>
 <option value="">Select…</option>${[5,4,3,2,1].map(n=><option value="${n}">${n} / 5</option>).join("")}
 </select></label>
 <p class="muted">After submission, this report will no longer be visible to the technician.</p>
 <button type="submit" id="submitFSR">Submit Completed Service</button>
 <button type="button" class="secondary" id="cancelFSR">Cancel</button>
 </form>`;
 const ts=signature($("techSign")),cs=signature($("customerSign"));
 $("clearTech").onclick=ts.clear;$("clearCustomer").onclick=cs.clear;
 $("cancelFSR").onclick=render;
 $("fsr").querySelectorAll("[data-check]").forEach(s=>s.onchange=()=>{
  const box=$("issue"+s.dataset.check),bad=s.value==="Not OK";
  box.hidden=!bad;
  box.querySelectorAll("input,textarea").forEach(el=>el.required=bad);
 });
 $("fsr").onsubmit=async e=>{
  e.preventDefault();
  if(!ts.valid()||!cs.valid())return notify("Both signatures are required.");
  const fd=new FormData(e.currentTarget);
  $("submitFSR").disabled=true;
  try{
   const report={
    id:uid(),jobId:job.id,generatorId:job.generatorId,technicianId:job.technicianId,
    completedDate:fd.get("completedDate"),submittedAt:new Date().toISOString(),
    readings:Object.fromEntries(readings.map(([label,key])=>[label,fd.get(key)])),
    checks:[],remarks:fd.get("remarks"),rating:fd.get("rating"),
    technicianSignature:ts.data(),customerSignature:cs.data(),
    before:await imageData(fd.get("before")),after:await imageData(fd.get("after")),
    delivery:"Not connected"
   };
   for(let i=0;i<checks.length;i++){
    const bad=fd.get("check"+i)==="Not OK";
    report.checks.push({
     name:checks[i],status:fd.get("check"+i),
     reason:bad?fd.get("reason"+i):"",
     photo:bad?await imageData(fd.get("photo"+i)):""
    });
   }
   commit(d=>{
    const current=d.jobs.find(j=>j.id===jobId);
    if(current.status!=="Assigned"||d.reports.some(r=>r.jobId===jobId))
     throw Error("This service has already been submitted.");
    const amc=d.amcs.find(a=>a.generatorId===job.generatorId
     &&a.start<=report.completedDate&&a.end>=report.completedDate);
    const month=report.completedDate.slice(0,7);
    report.classification="Non-AMC Service";
    if(amc){
     report.amcId=amc.id;
     if(amc.usedMonths.includes(month)){
      report.classification="Breakdown — no AMC deduction";
     }else if(amc.usedMonths.length<amc.visits){
      amc.usedMonths.push(month);
      report.classification="AMC Visit — 1 deducted";
     }else{
      report.classification="AMC visits exhausted — no deduction";
     }
    }
    const g=d.generators.find(x=>x.id===job.generatorId);
    report.snapshot={
     generator:structuredClone(g),
     customer:structuredClone(d.customers.find(x=>x.id===g.customerId)),
     technician:d.technicians.find(x=>x.id===job.technicianId)?.name
    };
    current.status="Completed";d.reports.push(report);
   });
   notify("Report submitted. WhatsApp delivery is not connected.");
   render();
  }catch(error){
   notify(error.name==="QuotaExceededError"
    ?"Browser storage is full. Use smaller photos; report was not saved."
    :error.message);
   if($("submitFSR"))$("submitFSR").disabled=false;
  }
 };
}
async function imageData(file){
 if(!(file instanceof File)||!file.size)throw Error("Required photo is missing.");
 if(!file.type.startsWith("image/"))throw Error("Please select an image.");
 if(file.size>12*1024*1024)throw Error("Each original photo must be under 12 MB.");
 const bitmap=await createImageBitmap(file);
 const scale=Math.min(1,1000/Math.max(bitmap.width,bitmap.height));
 const canvas=document.createElement("canvas");
 canvas.width=Math.max(1,Math.round(bitmap.width*scale));
 canvas.height=Math.max(1,Math.round(bitmap.height*scale));
 canvas.getContext("2d").drawImage(bitmap,0,0,canvas.width,canvas.height);
 bitmap.close();
 return canvas.toDataURL("image/jpeg",.7);
}
function reportsView(){
 $("app").innerHTML=db.reports.length?db.reports.slice().reverse().map(r=>`
 <div class="card"><h3>${esc(genName(r.generatorId))}</h3>
 <p>${esc(r.completedDate)} · ${esc(r.classification)}</p>
 <p class="muted">WhatsApp: not connected</p>
 <button data-report="${r.id}">View / Save PDF</button></div>`).join("")
 :empty("No reports submitted yet.");
 $("app").querySelectorAll("[data-report]").forEach(b=>b.onclick=()=>reportView(b.dataset.report));
}
function reportView(id){
 if($("role").value!=="owner")return render();
 const r=db.reports.find(x=>x.id===id);
 if(!r)return render();
 openedReport=r.id;
 const c=r.snapshot.customer,g=r.snapshot.generator;
 $("app").innerHTML=`
 <div class="row no-print" style="margin-bottom:15px">
 <button id="printReport">Print / Save PDF</button>
 <button class="secondary" id="backReports">Back to Reports</button>
 </div>
 <article class="card">
 <h2>SV Enterprises — Field Service Report</h2>
 <p><strong>Report:</strong> ${esc(r.id)}<br>
 <strong>Service date:</strong> ${esc(r.completedDate)}<br>
 <strong>Customer:</strong> ${esc(c.name)} · ${esc(c.phone)}<br>
 <strong>Address:</strong> ${esc(c.address)}<br>
 <strong>Generator:</strong> ${esc(g.make)} / ${esc(g.model)} / ${esc(g.kva)} kVA<br>
 <strong>Asset:</strong> ${esc(g.serial)}<br>
 <strong>Technician:</strong> ${esc(r.snapshot.technician)}<br>
 <strong>Classification:</strong> ${esc(r.classification)}</p>
 <h3>Readings</h3><div class="scroll"><table>
 ${Object.entries(r.readings).map(([k,v])=><tr><th>${esc(k)}</th><td>${esc(v)}</td></tr>).join("")}
 </table></div>
 <h3>Inspection</h3>
 ${r.checks.map(c=>`<div><p><strong>${esc(c.name)}:</strong> ${esc(c.status)}
 ${c.reason?<br>Reason: ${esc(c.reason)}:""}</p>
 ${c.photo?<div class="photos"><img src="${c.photo}" alt="Issue evidence"></div>:""}</div>`).join("")}
 <h3>Cleaning Photos</h3>
 <div class="grid photos">
 <div>Before<br><img src="${r.before}" alt="Before cleaning"></div>
 <div>After<br><img src="${r.after}" alt="After cleaning"></div>
 </div>
 <h3>Work Performed</h3><p style="white-space:pre-wrap">${esc(r.remarks)}</p>
 <p><strong>Customer Rating:</strong> ${esc(r.rating)} / 5</p>
 <div class="grid">
 <div><strong>Technician Signature</strong><br>
 <img class="signature" src="${r.technicianSignature}" alt="Technician signature"></div>
 <div><strong>Customer Signature</strong><br>
 <img class="signature" src="${r.customerSignature}" alt="Customer signature"></div>
 </div>
 </article>`;
 $("printReport").onclick=()=>window.print();
 $("backReports").onclick=render;
}
render();
</script>
</body>
</html>
