const root  = document.getElementById('root');
const vName = document.getElementById('v-name');
const vUid  = document.getElementById('v-uid');
const vCid  = document.getElementById('v-cid');
const vLic  = document.getElementById('v-lic');
const vLast = document.getElementById('v-last');
const btn   = document.getElementById('btnClose');

function openCard(data){
  vName.textContent = data?.name || '–';
  vUid.textContent  = data?.uid  || '–';
  vCid.textContent  = data?.cid  || '–';
  vLic.textContent  = data?.lic  || '–';
  vLast.textContent = data?.last_seen || '–';
  root.classList.remove('hidden');
}
function closeCard(){
  root.classList.add('hidden');
  fetch(`https://${GetParentResourceName()}/close`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}'
  }).catch(()=>{});
}

window.addEventListener('message', (e) => {
  const m = e.data; if(!m || !m.action) return;
  if (m.action === 'open') openCard(m.data);
  if (m.action === 'close') closeCard();
});

btn.addEventListener('click', closeCard);
window.addEventListener('keydown', (ev) => { if (ev.key === 'Escape') closeCard(); });
