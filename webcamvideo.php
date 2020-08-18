<br>
<div id="0">
<?php

    // the fotopath has to relative to index.php from the mainpage, the link below not!
    $mtime_webcamphoto = filemtime("../webcam/current.jpg");
    $override=0;
    //  time in seconds, i.e. after 2 hours of non existing update of the webcamfile we show the maintenance
    if ((!$mtime_webcamphoto or ((time() - $mtime_webcamphoto) >= (2*60*60))) or $override){
    ?>
        <a href="projects/webcam/maintenance.png" target="_blank"> <img class="webcamcontainer" id="webcammaintenance" src="projects/webcam/maintenance.png" alt=""></a>
    <?php
    } else {
    ?>
        <a href="../../../webcam/current.jpg" target="_blank"> <img class="webcamcontainer" src="../../../webcam/current.jpg" alt=""></a> 
    <?php
    }
?>

</div>
<div id="1">
<?php

    // the fotopath has to relative to index.php from the mainpage, the link below not!
    $mtime_webcamvideo = filemtime("../../webcam/current.webm");

    //  time in seconds, i.e. after 2 days of non existing update of the webcamfile we show the maintenance
    if ((!$mtime_webcamphoto or ((time() - $mtime_webcamphoto) >= (2*60*60))) or $override){
    // old check   
    // if (!$mtime_webcamvideo or ((time() - $mtime_webcamvideo) >= (2*60*60*24))){
    ?>
        <a href="projects/webcam/maintenance.png" target="_blank"> <img class="webcamcontainer" id="webcammaintenance" src="projects/webcam/maintenance.png" alt=""></a>
    <?php
    } else {
    ?>
        <video class="webcamcontainer" controls preload loop>
			<source src="../../../webcam/current.webm" type="video/webm">
			<source src="../../../webcam/current.mp4" type="video/mp4"> 
		Your browser does not support the video tag
		</video>
		<br>
		<br>
		<div id="timelapsespeed">Current Speed: 1</div>
		<button class="timelapsebutton" onclick="timelapseslower()">Slower</button>
		<button class="timelapsebutton" onclick="timelapsefaster()">Faster</button>
		<br>
		<p><a href="../../../webcam/current.webm" target="_blank">For direct webm-video click here</a></p>
		<p><a href="../../../webcam/current.mp4" target="_blank">For direct mp4-video click here</a></p>

    <?php
    }
?>

</div>
<script>

function timelapsefaster(){
  var playbackrate = document.getElementsByClassName("webcamcontainer")[1].playbackRate;
  if (playbackrate  <= 8) {
    document.getElementsByClassName("webcamcontainer")[1].playbackRate *= 2;
  }
  var playbackrate = document.getElementsByClassName("webcamcontainer")[1].playbackRate;
  document.getElementById("timelapsespeed").innerHTML = document.getElementById("timelapsespeed").innerHTML.substr(0,document.getElementById("timelapsespeed").innerHTML.indexOf(':'))+': '+playbackrate;
}

function timelapseslower(){
  var playbackrate = document.getElementsByClassName("webcamcontainer")[1].playbackRate;
  if (playbackrate  >= 0.0625) {
    document.getElementsByClassName("webcamcontainer")[1].playbackRate /= 2;
  }
  var playbackrate = document.getElementsByClassName("webcamcontainer")[1].playbackRate;
  document.getElementById("timelapsespeed").innerHTML = document.getElementById("timelapsespeed").innerHTML.substr(0,document.getElementById("timelapsespeed").innerHTML.indexOf(':'))+': '+playbackrate;
}

window.addEventListener('blur', function() {
  document.getElementsByClassName("webcamcontainer")[1].pause();
});

window.addEventListener('focus', function() {
  document.getElementsByClassName("webcamcontainer")[1].play();
});

</script>
