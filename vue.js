

const app = new Vue({
  el: '#app',
  data: {
    impound:0,
    searchQuery:'',
    ui:false,
    features: [
      { label: 'Speed', value: 70 },
      { label: 'Fuel', value: 40 },
      { label: 'Durability', value: 60 },
    ],
    select:{
      name: 'Albany Hern', plate :'TEST2', id : 1, located : 'TEST', state : 0
    },
    car:[]
   },
   methods: {

    nuiPost(name, payload = {}) {
      return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload)
      }).then(response => response.json()).catch(() => ({}));
    },

    parked(){
      this.nuiPost('Parked', this.select.plate);
    },

    spawn(){
      this.nuiPost('SpawnVehicle', this.select);
    },

    info(item){
      this.select = {
        name : item.title,
        plate : item.plate,
        id : item.id,
        located: item.location,
        state : item.state,
        vehicle : item.vehicle,
        model : item.model,
        mods : item.mods,
        damage : item.damage
      }
      this.nuiPost('VehicleInfo', {data:item}).then(function(data){
        app.features = [
          { label: 'Speed', value: Math.floor(data.Speed || 0) },
          { label: 'Fuel', value: Math.floor(data.Fuel || 0) },
          { label: 'Durability', value: Math.floor(data.Traction || 0) },
        ];
      });
    },
      handleEventMessage(event) {
        const item = event.data;
        switch (item.data) {
          case 'GARAGE':
            this.ui = true;
            this.car = item.car;
            this.info(item.car[0]);
            let stateZeroCount = 0;
            if (Array.isArray(this.car)) {
              stateZeroCount = this.car.filter(c => c.state === 0).length;
            } else if (this.car.state === 0) {
              stateZeroCount = 1;
            }
            this.impound = item.impound || stateZeroCount;
            // console.log(` DÜŞ ARTIK A ${stateZeroCount}`);
            if (typeof this.car.mods === 'string') {
              try {
                this.car.mods = JSON.parse(this.car.mods);
              } catch (e) {
                console.error('JSON:', e);
              }
            }
            break;
            case 'CLOSE':
              this.ui = false;
              this.nuiPost('exit');
            break
        }
    },   
  }, 
    computed: {
      filteredCars() {
        return this.car.filter(vehicle => {
          return vehicle.title.toLowerCase().includes(this.searchQuery.toLowerCase());
        });
      }
    },
    created() {
      window.addEventListener('message', this.handleEventMessage);
    },
  })
  document.onkeyup = function (data) {
    if (data.which == 27) {
      app.ui = false;
      app.nuiPost('exit');
    }
  };
  let holding = false, lastRotate = 0;
  let direction = "", oldx = 0;
  document.addEventListener('mousedown', (e) => holding = true);
  document.addEventListener('mouseup', (e) => holding = false);
  document.addEventListener('mousemove', function(e) {
      if (e.pageX < oldx) { direction = "left" } else if (e.pageX > oldx) { direction = "right" }
      oldx = e.pageX;
      if (Date.now() - lastRotate < 50) return;
      if (direction == "left" && holding) {
          if (e.target.classList.contains("move")) {
              lastRotate = Date.now();
              app.nuiPost('rotateright');
          }
      }
      if (direction == "right" && holding) {
          if (e.target.classList.contains("move")) {
              lastRotate = Date.now();
              app.nuiPost('rotateleft');
          }
      }
  });
  
  document.addEventListener('wheel', function(e) {
      if (e.target.classList.contains("move")) {
          if (e.deltaY < 0) {
              app.nuiPost('zoomIn');
          } else {
              app.nuiPost('zoomOut');
          }
      }
  });
  
