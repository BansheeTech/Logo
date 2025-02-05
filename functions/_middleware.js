// U shoulnd't b looking at this file bro lmao

export async function onRequest(context) {
  const url = new URL(context.request.url);

  if (url.pathname !== "/") {
    return context.next();
  }

  const userAgent = context.request.headers.get("User-Agent") || "";

  const cliUserAgents = ["curl", "wget", "httpie", "fetch", "http-client", "aria2c"];

  const isCLI = cliUserAgents.some(cli => userAgent.toLowerCase().includes(cli));

  const destination = isCLI
    ? "https://get.homedock.cloud/homedock-os/install.sh"
    : "https://www.homedock.cloud/install";

  return Response.redirect(destination, 307);
}