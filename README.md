# GPU Diagnostics Dashboard

A live results page for my C++/CUDA GPU diagnostic tool. It shows a normal run and a fault-injection run from a real NVIDIA GPU, and its **Run again** button asks a Colab notebook to test the GPU again.

## How it fits together
- **Colab** runs the C++ tool on the GPU and sends the results here.
- **This website** (on Vercel) shows the latest results and the current status.
- **Upstash Redis** (free, added from Vercel) stores the results and the status.

Colab only ever sends requests out to the website, so it needs no tunnel or public address.

## Files
- `index.html`: the page
- `api/results.js`: get the latest results, or save new ones
- `api/status.js`: what's happening right now
- `api/run.js`: the Run again button
- `api/poll.js`: Colab checks in here every 5 seconds while listening
- `lib/store.js`: saving and loading data, and the deploy key check

## Set up (once)
1. **Deploy:** put this folder in a GitHub repository. On vercel.com, choose **Add New → Project**, import the repository and click **Deploy**. Leave all settings as they are.
2. **Add storage:** in your Vercel project, open **Storage**, choose **Upstash for Redis** (free plan), create a database and connect it to this project.
3. **Make a deploy key:** in **Settings → Environment Variables**, add `DEPLOY_KEY` with a password you make up. Only someone with this key can send results or click Run again.
4. **Redeploy:** in **Deployments**, open the latest one and click **Redeploy**, so the new settings take effect.
5. **Colab:** click the key icon in the left sidebar, add a secret named `DEPLOY_KEY` with the same password, and switch on **Notebook access**. Put your website address in step 6 of the notebook.

## Use it
- In Colab, run steps 1–7. In the control panel, click **Deploy to website** to send fresh results.
- To run from the website, click **Start listening for runs** in Colab, then **Run again** on the site. The first time, the site asks for your deploy key and remembers it in that browser.
- Visitors without the key can view results but can't start runs.

Colab only listens while the notebook is open. When it isn't, the website still shows the last results.
