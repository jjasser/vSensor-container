<h1>Darktrace vSensor containerization</h1>


<h4>The containerization is comprised of three main files:</h4>

<ul>
<li><strong>Dockerfile</strong> - the purpose of this file is to create a template with all the dependencies, libraries, configurations for the application.</li>
<li><strong>docker-compose.yml</strong> - this file is used to bring up multiple containers. In this context is used to pull environment variables.</li>
<li><strong>.env</strong> - used to define a few environment variables to pass into the Dockerfile</li>
</ul>

---

<h4>Usage instructions</h4>

<ol>
<li>Run <strong>docker-compose up</strong> to create the container</li>
</ol>

