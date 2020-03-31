<h1>Darktrace vSensor containerization</h1>


<h5>The containerization is comprised of three main files:</h5>

<ul>
<li> **Dockerfile** - the purpose of this file is to create a template with all the dependencies, libraries, configurations for the application.</li>
<li>**docker-compose.yml** - this file is used to bring up multiple containers. In this context is used to pull environment variables.</li>
<li>**.env** - used to define a few environment variables to pass into the Dockerfile</li>
</ul>

---

<h5>Usage instructions</h5>

<ol>
<li>Run ```**docker-compose up**``` to create the container</li>
</ol>

