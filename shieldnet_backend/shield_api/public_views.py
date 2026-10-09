from django.shortcuts import render

def help_center_view(request):
    """
    Centre d'assistance et FAQ public ShieldNet.
    Accessible sans authentification par l'application mobile et les abonnés.
    """
    return render(request, 'public/help_center.html', {
        'page_title': "Centre d'Assistance & FAQ"
    })


def app_launch_view(request):
    """
    Page de redirection automatique et manuelle pour ouvrir l'application ShieldNet.
    Supporte les deep links shieldnet:// depuis les courriels ou navigateurs.
    """
    return render(request, 'public/app_open.html')
