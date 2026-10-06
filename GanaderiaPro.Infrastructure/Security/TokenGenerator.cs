using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using GanaderiaPro.Application.Common;
using GanaderiaPro.Application.Interfaces;
using GanaderiaPro.Domain.Entities;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace GanaderiaPro.Infrastructure.Security;

public class TokenGenerator : ITokenGenerator
{
    private readonly IConfiguration _configuration;

    public TokenGenerator(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public string GenerarToken(Usuario usuario)
    {
        var clave = _configuration["Jwt:SigningKey"]
            ?? throw new InvalidOperationException("Falta configurar Jwt:SigningKey (dotnet user-secrets).");

        var credenciales = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(clave)),
            SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub, usuario.Id.ToString()),
            new Claim("ranchoId", usuario.RanchoId.ToString()),
            new Claim("rol", usuario.Rol.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, usuario.Email),
            new Claim(ClaimSesion.Version, usuario.VersionSesion.ToString()),
        };

        var token = new JwtSecurityToken(
            claims: claims,
            expires: DateTime.UtcNow.AddHours(8),
            signingCredentials: credenciales);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
