const { error } = require("jquery");
const mongoose=require("mongoose")
const connectionString="mongodb://127.0.0.1:27017/huntintool"


mongoose.connect(connectionString)
.then(()=>{
    console.log('connection successfully');
}).
catch((error)=>{
    console.log('connection field');
    console.log(error);
})
