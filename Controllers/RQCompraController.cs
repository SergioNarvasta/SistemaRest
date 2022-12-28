﻿using Dapper;
using HDProjectWeb.Models;
using HDProjectWeb.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Configuration;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.Formatters;
using HDProjectWeb.Models.Detalles;

namespace HDProjectWeb.Controllers
{
    public class RQCompraController :Controller
    {
        private readonly IRepositorioRQCompra repositorioRQCompra;
        private readonly IServicioEstandar servicioEstandar;
        private readonly IServicioUsuario servicioUsuario;

        public RQCompraController(IRepositorioRQCompra repositorioRQCompra,IServicioEstandar servicioEstandar, IServicioUsuario servicioUsuario) 
        {
            this.repositorioRQCompra = repositorioRQCompra;
            this.servicioEstandar     = servicioEstandar;
            this.servicioUsuario = servicioUsuario;
        }

        [HttpGet]
        public IActionResult Crear()
        {
            RQCompra crear = new();
            var periodo = servicioEstandar.ObtenerPeriodo();
            var date = DateTime.Now;
            ViewBag.periodo = periodo;
            string coduser = servicioUsuario.ObtenerCodUsuario();
            string codaux = servicioUsuario.ObtenerCodAuxUsuario(coduser);
            crear.Rco_fec_registro = date;
            crear.S10_usuario = codaux;
            crear.S10_nomusu = servicioUsuario.ObtenerNombreUsuario(codaux);
            ViewBag.estado = "1";
           
            return View(crear);
        }

        [HttpPost]
        public async Task<IActionResult> Crear(RQCompra rQCompra)
        {
            /*if(!ModelState.IsValid)
            {
                return View(rQCompra); 
            }  */    
            rQCompra.Cia_codcia = servicioEstandar.Compañia();
            rQCompra.Suc_codsuc = servicioEstandar.Sucursal();
            rQCompra.Ano_codano = servicioEstandar.Ano();
            rQCompra.Mes_codmes = servicioEstandar.Mes();
            rQCompra.Rco_usucre = servicioUsuario.ObtenerCodUsuario();
            rQCompra.Rco_codusu = servicioUsuario.ObtenerCodUsuario();
            await repositorioRQCompra.Crear(rQCompra);

            foreach(DetalleReq detalleReq in rQCompra.ListaDetalles )
            {
               //await servicioDetalle.Crear(DetalleReq);
            }
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> Index(string periodo,string busqueda,string estado,string orden) 
        {
            if(periodo is not null)
            {
               await servicioEstandar.ActualizaPeriodo(periodo);
            }
            if (orden is not null)
            {
               await servicioEstandar.ActualizaOrden(orden);
            }
            orden =await servicioEstandar.ObtenerOrden();
            periodo = await servicioEstandar.ObtenerPeriodo();
            ViewBag.periodo = periodo.Remove(4, 2) + "-" + periodo.Remove(0, 4);
            PaginacionViewModel paginacionViewModel = new();
            string CodUser = servicioUsuario.ObtenerCodUsuario();        
            string estado1, estado2;
            if (estado == "2")
            {
                estado1 = "1"; estado2 = "0";
            }
            else
            {
                estado1 = estado; estado2 = estado;
            }
            if (busqueda is not null)
            {               
                var bus_rQCompra = await repositorioRQCompra.BusquedaMultiple(periodo, paginacionViewModel, CodUser, busqueda, estado1,estado2);
                var bus_totalRegistros = await repositorioRQCompra.ContarRegistrosBusqueda(periodo, CodUser, busqueda, estado1, estado2);
                var respuesta = new PaginacionRespuesta<RQCompraCab>
                {
                    Elementos = bus_rQCompra,
                    Pagina = paginacionViewModel.Pagina,
                    RecordsporPagina = paginacionViewModel.RecordsPorPagina,
                    CantidadRegistros = bus_totalRegistros,
                    BaseURL = Url.Action()
                };
                return View(respuesta);
            }
            else
            {
                var rQCompra = await repositorioRQCompra.Obtener(periodo, paginacionViewModel, CodUser, orden, estado1, estado2);
                var totalRegistros = await repositorioRQCompra.ContarRegistros(periodo, CodUser, estado1, estado2);
                var respuesta = new PaginacionRespuesta<RQCompraCab>
                {
                    Elementos = rQCompra,
                    Pagina = paginacionViewModel.Pagina,
                    RecordsporPagina = paginacionViewModel.RecordsPorPagina,
                    CantidadRegistros = totalRegistros,
                    BaseURL = Url.Action()
                };
                return View(respuesta);
            }                        
        }
        [Authorize]
        [HttpGet]
        public async Task<IActionResult> Index(PaginacionViewModel paginacionViewModel)
        {
            string estado1, estado2,estado="2";
            if (estado == "2")
            {
                estado1 = "1"; estado2 = "0";
            }
            else
            {
                estado1 = estado; estado2 = estado;
            }
            string orden = await servicioEstandar.ObtenerOrden();
            string CodUser = servicioUsuario.ObtenerCodUsuario();
            string periodo = await servicioEstandar.ObtenerPeriodo();
            ViewBag.periodo =  periodo.Remove(4,2)+"-"+periodo.Remove(0,4);         
            var rQCompra   = await repositorioRQCompra.Obtener(periodo,paginacionViewModel,CodUser, orden,  estado1, estado2);
            var totalRegistros = await repositorioRQCompra.ContarRegistros(periodo, CodUser, estado1, estado2);
            if (totalRegistros==0)
            {
                ViewBag.registros = "0";
            }
            var respuesta = new PaginacionRespuesta<RQCompraCab>
            {
                Elementos = rQCompra,
                Pagina = paginacionViewModel.Pagina,
                RecordsporPagina = paginacionViewModel.RecordsPorPagina,
                CantidadRegistros = totalRegistros,
                BaseURL = Url.Action()
            };
            return View(respuesta);
        }
      
        [HttpGet]
        public async Task<IActionResult> Editar(string Rco_Numero)
        {
            var rQCompra = await repositorioRQCompra.ObtenerporCodigo(Rco_Numero);
            if(rQCompra is null)
            {
                return RedirectToAction("NoEncontrado","Home");   
            }
            var periodo = servicioEstandar.ObtenerPeriodo();
            ViewBag.periodo = periodo;
            ViewBag.Rco_numero = Rco_Numero;
            return View("Crear",rQCompra);
        }

        [HttpPost]
        public  async Task<IActionResult> Editar(RQCompra rQCompraEd)
        {
           //var usuarioid=servicioEstandar.ObtenerPeriodo(); //ObtenerUsuarioId
           await repositorioRQCompra.Actualizar(rQCompraEd);
           return RedirectToAction("Index");
        }
    }
}